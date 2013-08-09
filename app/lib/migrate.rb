require_relative 'startup'
require_relative 'archon_client'
require_relative 'archivesspace_client'


class MigrationJob

  def initialize(params)
    @args = params

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

    repo_map = save_map.select{|k, v| v =~ /repositories/}

    # 2: Users (must use dedicated controller)
    Archon.record_type(:user).each do |rec|
      rec.class.transform(rec) do |obj|
        my_groups = []

        # superusers
        if rec["Usergroups"].include?("1")
          my_groups << "/repositories/1/groups/1"
        end        

        my_repos = rec["RepositoryLimit"] == "1" ? repo_map.reject{|k,v| rec!["Repositories"].include?(k)} : repo_map

        my_repos.each do |archon_id, aspace_uri|
          all_groups = @archivesspace.get_json("#{aspace_uri}/groups")
          rec["Usergroups"].each do |old_group_id|
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
        end

        obj.uri = nil
        result = obj.save(:password => "password", "groups[]" => my_groups.flatten)
        
        $log.debug("Save User result: #{result}")
      end
    end

    # 3: Everything else
    @archivesspace.import(y) do |batch|
      [
       :subject
      ].each do |key|
      
        Archon.record_type(key).each do |rec|
          $log.debug("Migrating Record: #{rec.inspect}")
          rec.class.transform(rec) do |obj|
            batch << obj
          end
        end
      end
    end
  end
end
