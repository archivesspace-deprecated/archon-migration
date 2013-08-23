require_relative 'startup'
require_relative 'archon_client'
require_relative 'archivesspace_client'


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

  end


  def connection_check
    if @archon.has_session? && @archivesspace.has_session?
      $log.debug("All systems go")
    else
      $log.warn("Not connected")
    end
  end


  def migrate(y)
    Thread.current[:selected_repo_id] = 1

    # 1: Repositories
    save_map = @archivesspace.import(y) do |batch|

      [
       :repository
      ].each do |key|

        Archon.record_type(key).each do |rec|
          $log.debug("Migrating Record #{rec.inspect}")
          rec.class.transform(rec) do |obj|
            batch << obj
          end
        end
      end
    end

    @repo_map = save_map.select{|k, v| v =~ /repositories/}

    # 2: Users (must use dedicated controller)
    Archon.record_type(:user).each do |rec|
      rec.class.transform(rec) do |obj|
        my_groups = []

        # superusers
        if rec["Usergroups"].include?("1")
          my_groups << "/repositories/1/groups/1"
        end        

        my_repos = rec["RepositoryLimit"] == "1" ? @repo_map.reject{|k,v| rec!["Repositories"].include?(k)} : @repo_map

        my_repos.each do |archon_id, aspace_uri|
          all_groups = @archivesspace.get_json("#{aspace_uri}/groups")
          # take the lowest group ID
          old_group_id = rec["Usergroups"].sort.first
          group_codes = case old_group_id
                        when "1"
                          %w(repository-managers repository-project-managers)
                        when "2"
                          %w(repository-advanced-data-entry)
                        when "3"
                          %w(repository-basic-data-entry)
                        when "4"
                          %w(repository-viewers)
                        end
          group_codes.each do |gc|
            my_groups << all_groups.find{|g| g['group_code'] == gc}['uri']
          end
        end

        obj.uri = nil
        result = obj.save(:password => "password", "groups[]" => my_groups)
        
        $log.debug("Save User result: #{result}")
      end
    end

    # 3: Global scope objects
    @import_map = @archivesspace.import(y) do |batch|
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

    # Iterate through repositories
    @repo_map.each do |archon_repo_id, aspace_repo_uri|
      repo_id = aspace_repo_uri.sub(/.*\//,'')
      $log.debug("Importing content for repository #{repo_id}")

      @archivesspace.repo(repo_id).import(y) do |batch|

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
        if archon_repo_id = @args[:default_repository]
          Archon.record_type(:accession).each do |rec|
            # yields agents and accessions, so check type
            rec.class.transform(rec) do |obj|
              case obj.jsonmodel_type
              when 'accession'
                resolve_ids_to_links(rec, obj)
              end

              batch << obj
            end
          end
        end

        batch.write!
        
        # Collections
        Archon.record_type(:collection).each do |rec|
          next unless rec['RepositoryID'] == archon_repo_id
          rec.class.transform(rec) do |obj|

            resolve_ids_to_links(rec, obj) 

            batch << obj

            # Content records
            container_trees = {}

            Archon.record_type(:content).set(rec["ID"]).each do |rec|
              rec.class.transform(rec) do |obj_or_cont|
                if obj_or_cont.is_a?(Array)
                  unless container_trees.has_key?(obj_or_cont[0])
                    container_trees[obj_or_cont[0]] = []
                  end
                  container_trees[obj_or_cont[0]] << obj_or_cont[1]
                else
                  resolve_ids_to_links(rec, obj_or_cont)
                  batch << obj_or_cont
                end
              end
            end

            batch.each do |obj|
              next unless obj.jsonmodel_type == 'archival_object'
              container_data = (container_trees[obj.key] || [])
              cd = ancestor_containers(obj, batch, container_trees, container_data)

              if cd.count > 3
                raise "Container tree too big for ASpace"
              end

              unless cd.empty?
                container = ASpaceImport.JSONModel(:container).new
                cd.each_with_index do |data, i|
                  container.send("type_#{i+1}=", data[:type])
                  container.send("indicator_#{i+1}=", data[:indicator])
                end
                
                instance = ASpaceImport.JSONModel(:instance).new
                instance.container = container
                instance.instance_type = 'text'

                obj.instances << instance
              end
            end
          end
        end
      end
    end
  end


  def ancestor_containers(obj, batch, container_trees, container_data)
    return container_data unless obj.parent


    parent_uri = obj.parent['ref']
    parent = batch.find {|objekt| objekt.uri == parent_uri}
    if container_trees.has_key?(parent.key)
      container_data = container_trees[parent.key] + container_data
    end

    return container_data if container_data.length > 2

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
end
