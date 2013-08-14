# Monkey patches for dismembered ArchivesSpace client tools

# don't run this code more than once
raise "bad reload" if defined?(ArchivesSpacePatches)

Kernel.module_eval do
  alias_method :orig_require, :require

  def require(*args)
    if args[0] =~ /(config-distribution|java)$/
      $log.debug("Skipping require: #{e}")
    else
      orig_require(*args) unless args[0] 
    end
  end
end


module AppConfig
  def self.[](*args)
    []
  end
end


module ArchivesSpacePatches

  def self.patch
    ASUtils.module_eval do
      def self.find_local_directories(*args)
        nil
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
  
