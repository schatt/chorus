require_relative '../../lib/shared/properties'
require 'set'

class ChorusConfig
  attr_accessor :config

  def initialize(root_dir=nil)
    set_root_dir(root_dir)
    app_config = {}
    app_config = Properties.load_file(config_file_path) if File.exists?(config_file_path)
    defaults = Properties.load_file(File.join(@root_dir, 'config/chorus.defaults.properties'))

    @config = ChorusConfig.deep_merge(defaults, app_config)

    secret_key_file = File.join(@root_dir, 'config/secret.key')
    abort "No config/secret.key file found.  Run rake development:init or rake development:generate_secret_key" unless File.exists?(secret_key_file)
    @config['secret_key'] = File.read(secret_key_file).strip
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

  def hdfs_versions
    @available_hdfs_versions ||= initialize_hdfs_versions
  end

  def hive_hdfs_versions
    @available_hive_hdfs_versions ||= initialize_hive_hdfs_versions
  end

  def time_zones
    us_zones = ActiveSupport::TimeZone.us_zones
    other_zones = ActiveSupport::TimeZone.all.reject { |z| us_zones.include?(z) }
    us_zones.map { |z| [ z.to_s, z.name ] } + [ [nil, nil] ] + other_zones.map { |z| [ z.to_s, z.name ] }
  end

  def gpfdist_configured?
    (self['gpfdist.url'] && self['gpfdist.write_port'] && self['gpfdist.read_port'] &&
        self['gpfdist.data_dir'] && self['gpfdist.ssl.enabled'] != nil)
  end

  def tableau_configured?
    !!(self['tableau.enabled'] && self['tableau.url'] && self['tableau.port'])
  end

  def tableau_sites
    if !self['tableau.sites'].nil?
      return self['tableau.sites'].map { |s| { 'name' => s } }
    else
      return []
    end
  end

  def gnip_configured?
    !!self['gnip.enabled']
  end

  def syslog_configured?
    (self['logging.syslog.enabled'] && true)
  end

  def kaggle_configured?
    return true if File.exist? Rails.root.join('demo_data', 'kaggleSearchResults.json')
    (self['kaggle.enabled'] && self['kaggle.api_key'] && true)
  end

  def oracle_configured?
    !!self['oracle.enabled'] && (File.exist? Rails.root.join('lib', 'libraries' , 'ojdbc6.jar'))
  end

  def oracle_driver_expected_but_missing?
    !!self['oracle.enabled'] && !(File.exist? Rails.root.join('lib', 'libraries', 'ojdbc6.jar'))
  end

  def self.config_file_path(root_dir=nil)
    root_dir = Rails.root unless root_dir
    File.join root_dir, 'config/chorus.properties'
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

  def log_level
    return :info unless self['logging'] && self['logging']['loglevel']

    level = self['logging']['loglevel'].to_sym

    if [:debug, :info, :warn, :error, :fatal].include? level
      level
    else
      :info
    end
  end

  def self.instance
    @instance ||= ChorusConfig.new
  end

  def server_port
    self['ssl.enabled'] ? self['ssl_server_port'] : self['server_port']
  end

  def public_url
    self['public_url']
  end

  def workflow_url
    self['work_flow.url'] || self['workflow.url']
  end

  def demo_enabled?
    self['demo_mode.enabled']
  end

  def mail_configuration
    self['mail']
  end

  def smtp_configuration
    self['smtp'].symbolize_keys
  end

  def database_login_timeout
    self['database_login_timeout']
  end

  def jdbc_schema_blacklists
    @schema_blacklists ||= initialize_schema_blacklists
  end

  def restrict_data_source_creation?
    !!self['models.data_source.restrict_creation']
  end

  private

  def initialize_hdfs_versions
    versions = []
    pivotal_versions = [
        'Pivotal HD 2',
        'Pivotal HD 3'
    ]
    other_versions = [
        'Cloudera CDH4',
        'Cloudera CDH5',
        'Cloudera CDH5.3',
        'Hortonworks HDP 2',
        'Hortonworks HDP 2.2',
        'IBM Big Insights 4.0',
        'MapR',
        'MapR4'
    ]
    versions += pivotal_versions
    versions += other_versions unless License.instance.branding == 'pivotal'
    versions.sort
  end

  def initialize_hive_hdfs_versions
    versions = [
        'Cloudera CDH5',
        'Hortonworks HDP 2',
        'IBM Big Insights 4.0',
        'MapR4'
    ]
    versions.sort
  end

  def initialize_schema_blacklists
    self['jdbc_schema_blacklist'].inject(Hash.new Set.new.freeze) do |memo, kv|
      memo[kv.first.to_sym] = Set.new(kv.last)
      memo
    end
  end

  def set_root_dir(root_dir)
    @root_dir = root_dir || Rails.root
  end
end
