require_relative 'startup'
require_relative 'archon_client'
require_relative 'archivesspace_client'
require_relative 'migration_helpers'
require 'zip'


class MigrationJob
  include MigrationHelpers

  def initialize(params = {})
    @args = params

    @args[:archon_url] ||= Appdata.default_archon_url
    @args[:archon_user] ||= Appdata.default_archon_user
    @args[:archon_password] ||= Appdata.default_archon_password

    @args[:aspace_url] ||= Appdata.default_aspace_url
    @args[:aspace_user] ||= Appdata.default_aspace_user
    @args[:aspace_password] ||= Appdata.default_aspace_password

    @args[:default_repository] ||= '1'
    @args[:do_baseurl] ||= 'http://example.com'

    Archon.record_type(:digitalfile).base_url = @args[:do_baseurl]

    @aspace = ArchivesSpace::Client.new(
                                        :url => @args[:aspace_url],
                                        :user => @args[:aspace_user],
                                        :password => @args[:aspace_password]
                                        )

    @archon = Archon::Client.new(
                                 :url => @args[:archon_url],
                                 :user => @args[:archon_user],
                                 :password => @args[:archon_password]
                                 )
    @unmigrated_records = {}

    unless File.exists?(Dir.tmpdir + "/archon_bitstreams")
      Dir.mkdir(Dir.tmpdir + "/archon_bitstreams") 
    end
    FileUtils.rm_rf(Dir.glob(Dir.tmpdir + "/archon_bitstreams/*"))

    download_path = File.join(File.dirname(__FILE__), '../', 'public', 'bitstreams.zip')

    if File.exists?(download_path)
      FileUtils.rm_rf(download_path)
    end

  end


  def all_good_or_die
    if !@archon.has_session? 
      raise "No Archon connection"
    elsif !@aspace.has_session?
      raise "No ArchivesSpace connection"
    elsif !@aspace.database_empty?
      raise "The ArchivesSpace instance you are connecting to is not empty. Please backup and delete the database"
    end
  end


  def migrate(y)
    all_good_or_die
    @y = y
    Thread.current[:selected_repo_id] = 1

    # 1: Repositories
    repo_and_agent_map = migrate_repo_records
    @repo_map = repo_and_agent_map.select {|k, v| v =~ /repositories/}

    # 2: Users
    migrate_users

    # 3: Global scope objects (agents and subjects)
    @globals_map = migrate_creators_and_subjects

    # 4: Iterate through repositories
    @repo_map.each do |archon_repo_id, aspace_repo_uri|
      migrate_repository(archon_repo_id, aspace_repo_uri)
    end

    # 5: Package Digital File content for Download
    package_digital_files
    emit_status("Migration complete. Download the log to review warnings")
  end


  def migrate_repository(archon_repo_id, aspace_repo_uri)
    emit_status("Migrating Repository #{archon_repo_id}")
    repo_id = aspace_repo_uri.sub(/.*\//,'')

    # Classifications
    classification_map = migrate_classifications(repo_id)

    # Accessions
    if archon_repo_id == @args[:default_repository]
      migrate_accessions(repo_id, classification_map)
    end

    # Collections and digital objects
    resource_maps = {}
    digital_instance_maps = {}
    Archon.record_type(:collection).each do |rec|
      next unless rec['RepositoryID'] == archon_repo_id
      coll_id = rec['ID']

      # Digital Objects
      digital_instance_maps[coll_id] = migrate_digital_objects(repo_id, 
                                                               coll_id, 
                                                               classification_map)

      # Resource Record
      resource_maps[coll_id] = migrate_collection(rec,
                                                  repo_id,
                                                  digital_instance_maps[coll_id],
                                                  classification_map)
    end

    # Resource Component Trees
    failures = []
    Archon.record_type(:collection).each(false) do |data|
      next unless data['RepositoryID'] == archon_repo_id
      coll_id = data['ID']
      migrate_collection_content(repo_id, 
                                 coll_id,
                                 resource_maps[coll_id],
                                 digital_instance_maps[coll_id], 
                                 classification_map)
    end
  end


  def migrate_collection(rec, 
                         repo_id,
                         digital_instance_map, 
                         classification_map)
    emit_status("Migrating Collection #{rec['ID']}", :update)
    @aspace.repo(repo_id).import(@y) do |batch|

      rec.class.transform(rec) do |resource|
        resolve_ids_to_links(rec, resource, classification_map)  
        rec.tap_locations do |location, instance|
          batch << location
          resource.instances << instance
        end

        # attach digital object instances
        import_id = rec.class.import_id_for(rec['ID'])
        if digital_instance_map && digital_instance_map[import_id]
          digital_instance_map[import_id].each do |do_uri|
            instance = ASpaceImport.JSONModel(:instance).new
            instance.instance_type = 'digital_object'
            instance.digital_object = {
              :ref => do_uri
            }
            resource.instances << instance
          end
        end

        batch << resource
      end
    end
  end


  def migrate_collection_content(repo_id, 
                                 coll_id, 
                                 resource_map,
                                 digital_instance_map, 
                                 classification_map)

    emit_status("Migrating Collection Content #{coll_id}", :update)

    i = 1
    5.times do
      emit_status("Attempt #{i}", :flash)
      i += 1
      result = @aspace.repo(repo_id).import(@y) do |batch|
        container_trees = {}
        position_tracker = {}
        position_map = {}

        Archon.record_type(:content).set(coll_id).each do |rec|
          import_id = rec.class.import_id_for(rec['ID'])
          rec.class.transform(rec) do |obj_or_cont|
            if obj_or_cont.is_a?(Array)
              cont = obj_or_cont
              unless container_trees.has_key?(cont[0])
                container_trees[cont[0]] = []
              end
              container_trees[cont[0]] << cont[1]
            else
              obj = obj_or_cont
              set_key = obj.parent.nil? ? nil : obj.parent['ref']
              position_tracker[set_key] ||= {}
              position_tracker[set_key][obj.position] ||= []
              position_tracker[set_key][obj.position] << obj.key

              resolve_ids_to_links(rec, obj_or_cont, classification_map)

              # link resource
              resource_uri = resource_map[import_id_for(:collection, coll_id)]
              obj.resource = {:ref => resource_uri}
              # attach digital object instances
              emit_status("Attaching digital object instances to Content record #{obj.title}", :flash)
              if digital_instance_map && digital_instance_map[import_id]
                digital_instance_map[import_id].each do |do_uri|
                  instance = ASpaceImport.JSONModel(:instance).new
                  instance.instance_type = 'digital_object'
                  instance.digital_object = {
                    :ref => do_uri
                  }
                  obj.instances << instance
                end
              end
              
              # check to make sure this is not an orthaned content record
              # before adding to the batch record array -- NS
              if obj.position != 99999999
              	  batch.unshift(obj_or_cont)
              else 
              	  emit_status("Skipping orthaned Content record #{obj.title}", :flash)
              end
            end
          end
        end

        # it might not be a bad idea to move this
        # to aspace one day
        emit_status("Adjusting positions for Content records in Collection #{coll_id}", :flash)
        position_tracker.each do |id, map|
          sorted = map.keys.sort
          sorted.each_with_index do |padded_position, real_position|
            map[padded_position].each do |obj_key|
              position_map[obj_key] = real_position
            end
          end
        end
        emit_status("Done adjusting positions", :flash)

        emit_status("Matching Content records to Containers", :flash)
        batch.each do |obj|
          if position_map.has_key?(obj.key)
            obj.position = position_map[obj.key]
          else
            obj.position = nil
          end

          if (container_data_sets = container_trees[obj.key])
            container_data_sets.each do |container_data|
              container = ASpaceImport.JSONModel(:container).new
              container_data.each_with_index do |data, i|
                container.send("type_#{i+1}=", (data[:type] || "unknown"))
                container.send("indicator_#{i+1}=", data[:indicator])
              end
              
              instance = ASpaceImport.JSONModel(:instance).new
              instance.container = container
              instance.instance_type = 'text'

              obj.instances << instance
            end
          end
        end
        emit_status("Done matching Content records to Containers", :flash)
      end

      break unless result == false
    end
  end


  def migrate_repo_records
    emit_status("Migrating Repository records")
    @aspace.import(@y) do |batch|

      Archon.record_type(:repository).each do |rec|
        rec.class.transform(rec) do |obj|
          batch << obj
        end
      end
    end
  end


  def migrate_users
    emit_status("Migrating User records")
    i = 0;

    Archon.record_type(:user).each do |rec|
      i = i + 1;
      rec.class.transform(rec) do |obj|
        my_groups = []

        # superusers
        if rec["Usergroups"].include?("1")
          my_groups << "/repositories/1/groups/1"
        end        

        my_repos = rec["RepositoryLimit"] == "1" ? @repo_map.reject{|k,v| rec["Repositories"].include?(k)} : @repo_map

        # take the lowest group ID
        old_group_id = rec["Usergroups"].sort.first
        if (group_codes = map_group_id(old_group_id))
          my_repos.each do |archon_id, aspace_uri|
            all_groups = @aspace.get_json("#{aspace_uri}/groups")
            group_codes.each do |gc|
              my_groups << all_groups.find{|g| g['group_code'] == gc}['uri']
            end
          end
        end

        obj.uri = nil
        result = obj.save(:password => "password", "groups[]" => my_groups)
        
        $log.debug("Save User result: #{result}")
      end
      if i.modulo(10) == 0
        emit_status("Saved #{i} records", :flash);
      end
    end
  end


  def migrate_creators_and_subjects
    emit_status("Migrating Creator and Subject records")
    import_map = @aspace.import(@y) do |batch|
      [
       :subject,
       :creator
      ].each do |key|
      
        i = 0;
        Archon.record_type(key).each do |rec|
          $log.debug("Migrating Record: #{rec.inspect}")
          rec.class.transform(rec) do |obj|
            batch << obj
          end
          i += 1
          if i.modulo(100) == 0
            emit_status("#{i} Archon records have been read", :flash)
          end
        end
      end
    end
    import_map
  end


  def migrate_classifications(repo_id)
    emit_status("Migrating Classification records", :update)
    @aspace.repo(repo_id).import(@y) do |batch|
      Archon.record_type(:classification).each do |rec|
        rec.class.transform(rec) do |obj|
          # set the creator (can't do this now; aspace issue
          # creator_uri = @globals_map[rec.import_id]
          # obj.creator = {'ref' => creator_uri}
          batch << obj
        end
      end
    end
  end


  def migrate_accessions(repo_id, classification_map)
    emit_status("Migrating Accession records", :update)
    @aspace.repo(repo_id).import(@y) do |batch|
      Archon.record_type(:accession).each do |rec|
        # yields agents and accessions, so check type
        rec.class.transform(rec) do |obj|

          if obj.jsonmodel_type == 'accession'
            resolve_ids_to_links(rec, obj, classification_map)
            rec.tap_locations do |location, instance|
              batch << location
              obj.instances << instance
            end
          end

          batch << obj
        end
      end
    end
  end


  def migrate_digital_objects(repo_id, coll_id, classification_map)
    emit_status("Migrating digital objects for Collection #{coll_id}", :update)
    instance_map = {}
    
    do_map = @aspace.repo(repo_id).import(@y) do |batch|
      digital_object_archon_ids = []
      Archon.record_type(:digitalcontent).each do |rec|

        next unless rec['CollectionID'] == coll_id
        digital_object_archon_ids << rec['ID']
        import_id = rec.class.import_id_for(rec['ID'])

        key1 = Archon.record_type(:collection).import_id_for(coll_id)
        instance_map[key1] ||= []
        instance_map[key1] << import_id

        rec.class.transform(rec) do |obj|
          resolve_ids_to_links(rec, obj, classification_map)

          if rec['CollectionContentID']
            key2 = Archon.record_type(:content).import_id_for(rec['CollectionContentID'])
            instance_map[key2] ||= []
            instance_map[key2] << import_id
          end

          batch << obj
        end
      end

      Archon.record_type(:digitalfile).each do |rec|
        next unless digital_object_archon_ids.include?(rec['DigitalContentID'])
 
        extract_bitstream(rec)

        rec.class.transform(rec) do |obj|
          batch.unshift(obj)
        end
      end
    end
    $log.debug(do_map.inspect);
    
    Hash[instance_map.map{|k, v| [k, v.map{|import_id| do_map[import_id]}]}]
  end


  def resolve_ids_to_links(rec, obj, classification_map)
    rec['Creators'].each do |id|
      import_id = Archon.record_type(:creator).import_id_for(id)
      if @globals_map.has_key?(import_id)
        obj.linked_agents << {
          :ref => @globals_map[import_id],
          :role => 'creator'
        }
      else
        $log.warn(%{Failed to link an ArchivesSpace #{obj.jsonmodel_type} record
to an Agent. The matching Archon ID for the #{obj.jsonmodel_type} record is
#{obj.key} and the matching Archon ID for the agent is #{id}})
      end
    end

    rec['Subjects'].each do |id|
      import_id = Archon.record_type(:subject).import_id_for(id)
      agent_or_subject_ref = @globals_map[import_id]
      if agent_or_subject_ref =~ /agents/
        obj.linked_agents << {
          :ref => agent_or_subject_ref,
          :role => 'subject'
        }
      else 
        obj.subjects << {
          :ref => @globals_map[import_id]
        }
      end
    end

    classification_import_id = get_classification_import_id(rec)

    if classification_import_id
      if classification_map.has_key?(classification_import_id)
        obj.classification = {:ref => classification_map[classification_import_id]}
      else
        $log.warn("Unable to link classification. Record title: #{obj.title}. Archon Classification Import ID: #{classification_import_id}")
      end
    end
  end


  def extract_bitstream(rec)
    endpoint = "/?p=core/digitalfileblob&fileid=#{rec['ID']}"

    filepath = File.new(find_bitstream_path(rec['Filename']), 'w')
    @archon.download_bitstream(endpoint, filepath)
  end


  def find_bitstream_path(name)
    path = Dir.tmpdir + "/archon_bitstreams/" + name
    return path
  end


  def associate_digital_instance(archival_object, digital_object)
    instance = ASpaceImport.JSONModel(:instance).new
    instance.instance_type = 'digital_object'
    instance.digital_object = {
      :ref => digital_object.uri
    }

    archival_object.instances << instance
  end


  def package_digital_files
    emit_status("Packaging digital files for download")
    directory = Dir.tmpdir + "/archon_bitstreams/"
    zipfile_name = File.join(File.dirname(__FILE__), '../', 'public', 'bitstreams.zip')
   
    Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
      Dir.glob("#{directory}*.*").each do |file|
        zipfile.add(file.sub(directory, ''), file)
      end
    end
  end
end


class MigrationLog

  def initialize(y, syslog)
    @y = y
    @syslog = syslog
  end


  def method_missing(method, *args)
    @syslog.send(method, *args)
  end


  def warn(warning)
    unless warning =~ /explicitly cleared from the cache/
      unless Appdata.mode == :server
        w = "#{warning[0,100]}...see log"
        @y << JSON.generate({:type => :warning, :body => w}) + "---\n"
      end
      @syslog.warn(warning)
    end
  end
end
