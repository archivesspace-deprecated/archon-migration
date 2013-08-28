require_relative 'startup'
require_relative 'archon_client'
require_relative 'archivesspace_client'
require 'zip/zip'


class MigrationJob

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

    # 1 job per thread
    raise "Job thread occupied." if Thread.current[:archon_migration_job]
    Thread.current[:archon_migration_job] = self


    @archivesspace = ArchivesSpace::Client.new(
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


  def connection_check
    if @archon.has_session? && @archivesspace.has_session?
      $log.debug("All systems go")
    else
      $log.warn("Not connected")
    end
  end


  def migrate(y)
    @y = y
    Thread.current[:selected_repo_id] = 1

    # 1: Repositories
    emit_status("Migrating Repository records")

    save_map = @archivesspace.import(@y) do |batch|

      [
       :repository
      ].each do |key|

        Archon.record_type(key).each do |rec|
          rec.class.transform(rec) do |obj|
            batch << obj
          end
        end
      end
    end

    @repo_map = save_map.select{|k, v| v =~ /repositories/}

    # 2: Users (must use dedicated controller)
    emit_status("Migrating User records")

    Archon.record_type(:user).each do |rec|
      rec.class.transform(rec) do |obj|
        my_groups = []

        # superusers
        if rec["Usergroups"].include?("1")
          my_groups << "/repositories/1/groups/1"
        end        

        my_repos = rec["RepositoryLimit"] == "1" ? @repo_map.reject{|k,v| rec["Repositories"].include?(k)} : @repo_map

        my_repos.each do |archon_id, aspace_uri|
          all_groups = @archivesspace.get_json("#{aspace_uri}/groups")
          # take the lowest group ID
          old_group_id = rec["Usergroups"].sort.first
          group_codes = map_group_id(old_group_id)
          group_codes.each do |gc|
            my_groups << all_groups.find{|g| g['group_code'] == gc}['uri']
          end
        end

        obj.uri = nil
        result = obj.save(:password => "password", "groups[]" => my_groups)
        
        $log.debug("Save User result: #{result}")
      end
    end

    emit_status("Migrating Creator and Subject records")
    # 3: Global scope objects
    @import_map = migrate_creators_and_subjects

    # 4: Iterate through repositories
    @repo_map.each do |archon_repo_id, aspace_repo_uri|
      migrate_repository(archon_repo_id, aspace_repo_uri)
    end

    # 5: Package Digital File content for Download
    package_digital_files
  end


  def ancestor_containers(obj, batch, container_trees, container_data)
    return container_data unless obj.parent

    parent_uri = obj.parent['ref']
    parent = batch.find {|objekt| objekt.uri == parent_uri}
    if container_trees.has_key?(parent.key)
      container_data = container_trees[parent.key] + container_data
    end

    return container_data[-3..-1] if container_data.length > 2

    ancestor_containers(parent, batch, container_trees, container_data)
  end


  def resolve_ids_to_links(rec, obj)
    rec['Creators'].each do |id|
      import_id = Archon.record_type(:creator).import_id_for(id)
      obj.linked_agents << {
        :ref => @import_map[import_id],
        :role => 'creator'
      }
    end


    rec['Subjects'].each do |id|
      import_id = Archon.record_type(:subject).import_id_for(id)
      agent_or_subject_ref = @import_map[import_id]
      if agent_or_subject_ref =~ /agents/
        obj.linked_agents << {
          :ref => agent_or_subject_ref,
          :role => 'subject'
        }
      else 
        obj.subjects << {
          :ref => @import_map[import_id]
        }
      end
    end
  end


  def emit_status(msg)
    @y << JSON.generate({:type => :status, :body => msg}) + "---\n"
  end


  def map_group_id(old_group_id)
    case old_group_id
    when "1"
      %w(repository-managers repository-project-managers)
    when "2"
      %w(repository-advanced-data-entry)
    when "3"
      %w(repository-basic-data-entry)
    when "4"
      %w(repository-viewers)
    end
  end


  def migrate_repository(archon_repo_id, aspace_repo_uri)

    emit_status("Migrating Repository #{archon_repo_id}")
    repo_id = aspace_repo_uri.sub(/.*\//,'')

    @archivesspace.repo(repo_id).import(@y) do |batch|

      # Classifications
      Archon.record_type(:classification).each do |rec|
        rec.class.transform(rec) do |obj|
          # set the creator (can't do this now; aspace issue
          # creator_uri = @import_map[rec.import_id]
          # obj.creator = {'ref' => creator_uri}
          batch << obj
        end
      end

      # Accessions
      if archon_repo_id == @args[:default_repository]
        Archon.record_type(:accession).each do |rec|
          # yields agents and accessions, so check type
          rec.class.transform(rec) do |obj|

            if obj.jsonmodel_type == 'accession'
              resolve_ids_to_links(rec, obj)
              rec.tap_locations do |location, instance|
                batch << location
                obj.instances << instance
              end
            end

            batch << obj
          end
        end
      end

      # Collections
      Archon.record_type(:collection).each do |rec|
        batch.write!
        next unless rec['RepositoryID'] == archon_repo_id
        rec.class.transform(rec) do |obj|

          if obj.jsonmodel_type == 'resource'
            resolve_ids_to_links(rec, obj)            
            rec.tap_locations do |location, instance|
              batch << location
              obj.instances << instance
            end

            process_resource_tree(batch, rec, obj) 
          end

          batch << obj
        end
      end
    end
  end


  def process_resource_tree(batch, rec, coll_obj)
    # Content records
    container_trees = {}

    Archon.record_type(:content).set(rec["ID"]).each do |content_rec|
      content_rec.class.transform(content_rec) do |obj_or_cont|
        if obj_or_cont.is_a?(Array)
          unless container_trees.has_key?(obj_or_cont[0])
            container_trees[obj_or_cont[0]] = []
          end
          container_trees[obj_or_cont[0]] << obj_or_cont[1]
        else
          resolve_ids_to_links(content_rec, obj_or_cont)
          batch << obj_or_cont
        end
      end
    end

    apply_container_trees(batch, container_trees)

    digital_object_archon_ids = []
    Archon.record_type(:digitalcontent).each do |digital_rec|
      next unless digital_rec['CollectionID'] == rec['ID']            
      digital_object_archon_ids << rec['ID']

      digital_rec.class.transform(digital_rec) do |obj|
        resolve_ids_to_links(digital_rec, obj)
        batch << obj

        if digital_rec['CollectionContentID']
          content_obj = batch.find{|o| o.key == digital_rec['CollectionContentID'] && o.jsonmodel_type == 'archival_object'}

          if content_obj
            associate_digital_instance(content_obj, obj)
          else
            $log.warn("Failed to find an archival_object record")
          end
        else
          associate_digital_instance(coll_obj, obj)
        end
      end
    end

    Archon.record_type(:digitalfile).each do |rec|
      next unless digital_object_archon_ids.include?(rec['DigitalContentID'])
      
      extract_bitstream(rec)

      rec.class.transform(rec) do |obj|
        batch << obj
      end
    end
  end


  def extract_bitstream(rec)
    endpoint = "/?p=core/digitalfileblob&fileid=#{rec['ID']}"
#    filepath = Tempfile.new(rec['Filename'], Dir.tmpdir + "/archon_bitstreams/")
    filepath = File.new(Dir.tmpdir + "/archon_bitstreams/" + rec['Filename'], 'w')
    @archon.download_bitstream(endpoint, filepath)
  end


  def associate_digital_instance(archival_object, digital_object)
    instance = ASpaceImport.JSONModel(:instance).new
    instance.instance_type = 'digital_object'
    instance.digital_object = {
      :ref => digital_object.uri
    }

    archival_object.instances << instance
  end


  def apply_container_trees(batch, container_trees)
    batch.each do |obj|
      next unless obj.jsonmodel_type == 'archival_object'
      container_data = (container_trees[obj.key] || [])
      cd = ancestor_containers(obj, batch, container_trees, container_data)

      if cd.count > 3
        $log.debug("Container Data: #{cd.inspect}")
        raise "Container tree too big for ASpace"
      end

      unless cd.empty?
        container = ASpaceImport.JSONModel(:container).new
        cd.each_with_index do |data, i|
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


  def migrate_creators_and_subjects
    import_map = @archivesspace.import(@y) do |batch|
      [
       :subject,
       :creator
      ].each do |key|
      
        Archon.record_type(key).each do |rec|
          $log.debug("Migrating Record: #{rec.inspect}")
          rec.class.transform(rec) do |obj|
            batch << obj
          end
        end
      end
    end

    import_map
  end


  def package_digital_files
    directory = Dir.tmpdir + "/archon_bitstreams/"
#    zipfile_name = File.expand_path('bitstreams.zip', settings.public)
    zipfile_name = File.join(File.dirname(__FILE__), '../', 'public', 'bitstreams.zip')
   
    Zip::ZipFile.open(zipfile_name, Zip::ZipFile::CREATE) do |zipfile|
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
      @y << JSON.generate({:type => :warning, :body => warning}) + "---\n"
    end
    @syslog.warn(warning)
  end
end
