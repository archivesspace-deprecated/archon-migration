require_relative 'archon_record'


class MigrationController


  def self.migrate
    Archon.record_type(:subject).each do |id, subject|

      puts "Migrating Record: #{id}"
    end
  end
end
