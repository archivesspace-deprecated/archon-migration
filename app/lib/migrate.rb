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

    #open up the batch file
    @archivesspace.import(y) do |batch|

      [
       :repository,
       :subject
      ].each do |key|
      
        Archon.record_type(key).each do |rec|
          $log.debug("Migrating Record: #{rec.inspect}")
          batch << rec.class.transform(rec)
        end
      end
    end
  end
end



