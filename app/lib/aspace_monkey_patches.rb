# Monkey patches for dismembered ArchivesSpace client tools
module AppConfig
  def self.[](*args)
    []
  end
end


module ArchivesSpacePatches

  def self.patch_in(&block)
    Kernel.module_eval do
      alias_method :orig_require, :require

      def require(*args)
        if args[0] =~ /(config-distribution|java)$/
          $log.debug("Skipping require: #{args[0]}")
        else
          orig_require(*args)
        end
      end
    end

    block.call

    Kernel.module_eval do
      alias_method :require, :orig_require
    end

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
  
