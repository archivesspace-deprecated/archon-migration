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
      
      Archon.record_type(:subject).each do |id, subject|

        $log.debug("Migrating Record: #{id}")

        if %w(3 8 10).include?(subject["SubjectTypeID"])
          # build an agent
        else
          # build a subject

          terms = build_terms(subject)

          # ASpaceImport.JSONModel(:subject).from_hash({
          #                                              #:external_ids => [{:external_id => subject["ID"]}],
          #                                              :terms => terms
          #                                             })

          s = JSONModel.JSONModel(:subject).new
          s.uri = s.class.uri_for(subject["ID"])
          s.terms = terms
          s.vocabulary = '/vocabularies/1'
          batch << s
        end
      end
    end
  end


  def build_terms(subject, terms = [])
    if subject["Parent"]
      terms = build_terms(subject["Parent"], terms)
    end

    terms << {:term => subject["Subject"], :term_type => term_type(subject["SubjectTypeID"]), :vocabulary => '/vocabularies/1'}

    terms
  end


  def term_type(archon_subject_type_id)
    case archon_subject_type_id
    when '4'; 'function'
    when '5'; 'genre_form'
    when '6'; 'geographic'
    when '7'; 'occupation'
    when '2'; 'temporal'
    when '1'; 'topical'
    when '9'; 'uniform_title'
    end
  end
end



