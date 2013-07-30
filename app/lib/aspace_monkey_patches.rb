# Monkey patches for dismembered ArchivesSpace client tools

ASUtils.module_eval do
  def self.find_local_directories(*args)
    nil
  end
end


module AppConfig
  def self.[](*args)
    []
  end
end


JSONModel.module_eval do
  def self.backend_url
    Thread.current[:archivesspace_url]
  end


  def self.init_args
    InitArgs
  end


  def self.client_mode?
    true
  end
end


JSONModel::HTTP.module_eval do
   def self.backend_url
     Thread.current[:archivesspace_url]
   end
end


class InitArgs
  def self.[](arg)
    case arg
    when :enum_source
      Thread.current[:archivesspace_client].enum_source
    end
  end
end  
  
