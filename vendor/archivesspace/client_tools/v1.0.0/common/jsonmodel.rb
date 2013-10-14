require 'json-schema'
require 'atomic'
require 'uri'
require_relative 'jsonmodel_type'
require_relative 'json_schema_concurrency_fix'
require_relative 'json_schema_utils'
require_relative 'asutils'
require_relative 'validator_cache'


module JSONModel

  @@models = {}
  @@custom_validations = {}
  @@strict_mode = false


  def self.custom_validations
    @@custom_validations
  end

  def strict_mode(val)
    @@strict_mode = val
  end


  def self.strict_mode?
    @@strict_mode
  end


  class ValidationException < StandardError
    attr_accessor :invalid_object
    attr_accessor :errors
    attr_accessor :warnings
    attr_accessor :attribute_types

    def initialize(opts)
      @invalid_object = opts[:invalid_object]
      @errors = opts[:errors]
      @attribute_types = opts[:attribute_types]
    end

    def to_s
      "#<:ValidationException: #{{:errors => @errors}.inspect}>"
    end
  end


  def self.JSONModel(source)
    if !@@models.has_key?(source.to_s)
      load_schema(source.to_s)
    end

    @@models[source.to_s] or raise "JSONModel not found for #{source}"
  end


  def JSONModel(source)
    JSONModel.JSONModel(source)
  end


  # Yield all known JSONModel classes
  def models
    @@models
  end


  def self.repository_for(reference)
    if reference =~ /^(\/repositories\/[0-9]+)\//
      return $1
    else
      return nil
    end
  end


  # Parse a URI reference like /repositories/123/archival_objects/500 into
  # {:id => 500, :type => :archival_object}
  def self.parse_reference(reference, opts = {})
    @@models.each do |type, model|
      id = model.id_for(reference, opts, true)
      if id
        return {:id => id, :type => type, :repository => repository_for(reference)}
      end
    end

    nil
  end


  def self.destroy_model(type)
    @@models.delete(type.to_s)
  end


  def self.schema_src(schema_name)

    if schema_name.to_s !~ /\A[0-9A-Za-z_-]+\z/
      raise "Invalid schema name: #{schema_name}"
    end

    [*ASUtils.find_local_directories('schemas'),
     File.join(File.dirname(__FILE__), "schemas")].each do |dir|

      schema = File.join(dir, "#{schema_name}.rb")

      if File.exists?(schema)
        return File.open(schema).read
      end
    end

    nil
  end


  def self.allow_unmapped_enum_value(val, magic_value = 'other_unmapped')
    if val.is_a? Array
      val.each { |elt| allow_unmapped_enum_value(elt) }
    elsif val.is_a? Hash
      val.each do |k, v|
        if k == 'enum'
          v << magic_value
         else
          allow_unmapped_enum_value(v)
        end
      end
    end
  end


  def self.load_schema(schema_name)
    if not @@models[schema_name]

      old_verbose = $VERBOSE
      $VERBOSE = nil
      src = schema_src(schema_name)

      return if !src

      entry = eval(src)
      $VERBOSE = old_verbose

      parent = entry[:schema]["parent"]
      if parent
        load_schema(parent)

        base = @@models[parent].schema["properties"].clone
        properties = self.deep_merge(base, entry[:schema]["properties"])

        # Maybe we'll eventually want the version of a schema to be
        # automatically set to max(my_version, parent_version), but for now...
        if entry[:schema]["version"] < @@models[parent].schema_version
          raise ("Can't inherit from a JSON schema whose version is newer than ours " +
                 "(our (#{schema_name}) version: #{entry[:schema]['version']}; " +
                 "parent (#{parent}) version: #{@@models[parent].schema_version})")
        end

        entry[:schema]["properties"] = properties
      end

      # All records have a lock_version property that we use for optimistic concurrency control.
      entry[:schema]["properties"]["lock_version"] = {"type" => ["integer", "string"], "required" => false}

      # All records must indicate their model type
      entry[:schema]["properties"]["jsonmodel_type"] = {"type" => "string", "ifmissing" => "error"}

      # All records have audit fields
      entry[:schema]["properties"]["created_by"] = {"type" => "string", "readonly" => true}
      entry[:schema]["properties"]["last_modified_by"] = {"type" => "string", "readonly" => true}
      entry[:schema]["properties"]["user_mtime"] = {"type" => "date-time", "readonly" => true}
      entry[:schema]["properties"]["system_mtime"] = {"type" => "date-time", "readonly" => true}
      entry[:schema]["properties"]["create_time"] = {"type" => "date-time", "readonly" => true}

      # Records may include a reference to the repository that contains them
      entry[:schema]["properties"]["repository"] ||= {
        "type" => "object",
        "subtype" => "ref",
        "readonly" => "true",
        "properties" => {
          "ref" => {
            "type" => "JSONModel(:repository) uri",
            "ifmissing" => "error",
            "readonly" => "true"
          },
          "_resolved" => {
            "type" => "object",
            "readonly" => "true"
          }
        }
      }


      if @@init_args[:allow_other_unmapped]
        allow_unmapped_enum_value(entry[:schema]['properties'])
      end

      AppConfig[:plugins].each do |plugin|
        Dir.glob(File.join('..', 'plugins', plugin, 'schemas', "#{schema_name}_ext.rb")).each do |ext|
          entry[:schema]['properties'] = self.deep_merge(entry[:schema]['properties'],
                                                         eval(File.open(ext).read))
        end
      end

      self.create_model_for(schema_name, entry[:schema])
    end
  end


  def self.init(opts = {})

    @@init_args ||= nil

    # Skip initialisation if this model has already been loaded.
    if @@init_args
      return true
    end

    if opts.has_key?(:strict_mode)
      @@strict_mode = true
    end

    @@init_args = opts

    if !opts.has_key?(:enum_source)
      if opts[:client_mode]
        require_relative 'jsonmodel_client'
        opts[:enum_source] = JSONModel::Client::EnumSource.new
      else
        raise "Required JSONModel.init arg :enum_source was missing"
      end
    end

    # Load all JSON schemas from the schemas subdirectory
    # Create a model class for each one.
    Dir.glob(File.join(File.dirname(__FILE__),
                       "schemas",
                       "*.rb")).sort.each do |schema|
      schema_name = File.basename(schema, ".rb")
      load_schema(schema_name)
    end

    require_relative "validations"

    # For dynamic enums, automatically slot in the 'other_unmapped' string as an allowable value
    if @@init_args[:allow_other_unmapped]
      enum_wrapper = Struct.new(:enum_source).new(@@init_args[:enum_source])

      def enum_wrapper.valid?(name, value)
        value == 'other_unmapped' || enum_source.valid?(name, value)
      end


      def enum_wrapper.values_for(name)
        enum_source.values_for(name) + ['other_unmapped']
      end

      def enum_wrapper.default_value_for(name)
        enum_source.default_value_for(name)
      end

      @@init_args[:enum_source] = enum_wrapper
    end

    true

  rescue
    # If anything went wrong we're not initialised.
    @@init_args = nil

    raise $!
  end


  def self.enum_values(name)
    @@init_args[:enum_source].values_for(name)
  end


  def self.enum_default_value(name)
    @@init_args[:enum_source].default_value_for(name)
  end


  def self.client_mode?
    @@init_args[:client_mode]
  end


  def self.parse_jsonmodel_ref(ref)
    if ref.is_a? String and ref =~ /JSONModel\(:([a-zA-Z_\-]+)\) (.*)/
      [$1.intern, $2]
    else
      nil
    end
  end

  # Recursively overlays hash2 onto hash 1
  def self.deep_merge(hash1, hash2)
    target = hash1.dup
    hash2.keys.each do |key|
      if hash2[key].is_a? Hash and hash1[key].is_a? Hash
        target[key] = self.deep_merge(target[key], hash2[key])
        next
      end
      target[key] = hash2[key]
    end
    target
  end

  protected


  def self.clean_data(data)
    data = ASUtils.keys_as_strings(data) if data.is_a?(Hash)
    data = ASUtils.jsonmodels_to_hashes(data)

    data
  end


  # Create and return a new JSONModel class called 'type', based on the
  # JSONSchema 'schema'
  def self.create_model_for(type, schema)

    cls = Class.new(JSONModelType)
    cls.init(type, schema, Array(@@init_args[:mixins]))

    @@models[type] = cls
  end


  def self.init_args
    @@init_args
  end

end


# Custom JSON schema validations
require_relative 'archivesspace_json_schema'
