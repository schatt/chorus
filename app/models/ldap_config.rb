require_relative '../../lib/shared/properties'
require 'set'

class LdapConfig
  attr_accessor :config

  def initialize(root_dir=nil)
    set_root_dir(root_dir)
    ldap_config = {}

    @config = Properties.load_file(config_file_path) if config_file_exists?
    check_configuration_validity
  end



  def self.exists?
    config = self.instance.config
    config && config['ldap'] && config['ldap']['enable'].present?
  end

  def config
    @config
  end

  def [](key_string)
    keys = key_string.split('.')
    keys.inject(@config) do |hash, key|
      hash.fetch(key)
    end
  rescue IndexError
    nil
  end

   def with_temporary_config(new_config_hash)
     old_config = @config.deep_dup
     @config.deep_merge! new_config_hash.stringify_keys
     yield
   ensure
     @config = old_config
   end

  def self.config_file_path(root_dir=nil)
    root_dir = Rails.root unless root_dir
    File.join root_dir, 'config/ldap.properties'
  end

  def config_file_path
    self.class.config_file_path(@root_dir)
  end

  def self.deep_merge(hash, other_hash)
    deep_merge!(hash.dup, other_hash)
  end

  def self.deep_merge!(hash, other_hash)
    other_hash.each_pair do |k,v|
      tv = hash[k]
      hash[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? deep_merge(tv, v) : v
    end
    hash
  end

  def self.instance
    @instance ||= LdapConfig.new
  end

  private

  def config_file_exists?
     if File.symlink?(config_file_path)
      File.exists?(File.readlink(config_file_path))
    else
      File.exists?(config_file_path)
    end
  end

  def set_root_dir(root_dir)
    @root_dir = root_dir || Rails.root
  end

  def check_configuration_validity

    return if @config.nil? || @config['ldap'].nil? || @config['ldap']['enable'].nil? || @config['ldap']['enable'] == false

    # will raise error if one of these properties is missing
    required_properties = [
        'enable',
        'host',
        'port',
        { 'bind' => ['username', 'password' ] },
        { 'user' => ['search_base', 'filter'] }
    ]


    mutually_dependent_properties = [
        { 'group' => ['names', 'search_base', 'filter'] }
    ]

    required_properties.each do |prop|
      if prop.is_a? String
        raise LdapClient::LdapNotCorrectlyConfigured.new("Missing value for property ldap.#{prop} in ldap.properties file") if @config["ldap"][prop].nil?
      end

      if prop.is_a? Hash
        attribute = prop.keys.first
        nested_props = prop.values.first
        nested_props.each do |nested_prop|
          if @config["ldap"][attribute].nil? || @config["ldap"][attribute][nested_prop].nil?
            raise LdapClient::LdapNotCorrectlyConfigured.new("Missing value for property ldap.#{attribute}.#{nested_prop} in ldap.properties file")
          end
        end
      end
    end

    mutually_dependent_properties.each do |prop|
      if prop.is_a? Hash
        attribute = prop.keys.first
        nested_props = prop.values.first

        # If the whole group is missing, it's ok.
        return if @config['ldap'][attribute].nil?

        # Otherwise, make sure all of the properties exist
        is_valid = nested_props.all? do |nested_prop|
          @config['ldap'][attribute].key?(nested_prop) && !@config["ldap"][attribute][nested_prop].nil?
        end

        all_props_string = nested_props.inject("") {|result, nested_prop| "#{result} #{attribute}.#{nested_prop}"}
        raise LdapClient::LdapNotCorrectlyConfigured.new("One or more of these LDAP settings are mis-configured: (#{all_props_string}). Please contact your system administrator.") unless is_valid
      end
    end
  end

end
