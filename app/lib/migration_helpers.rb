module MigrationHelpers
  def emit_status(msg, type=:status)
    @y << JSON.generate({:type => type, :body => msg}) + "---\n"
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
    else
      $log.warn("Unable to interpet Archon Group ID: #{old_group_id}. Ignoring")
      false
    end
  end


  def bounded_containers(container_data)
    if container_data.length > 2
      container_data[-3..-1]
    else
      container_data
    end
  end


  def get_classification_import_id(rec)
    id = if rec.has_key?('Classifications')
           rec['Classifications'][0]
         elsif rec.has_key?('ClassificationID')
           rec['ClassificationID']
         else 
           nil
         end

    id ? Archon.record_type(:classification).import_id_for(id) : nil
  end
end
