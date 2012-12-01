require 'fileutils'
require 'securerandom'
require 'yaml'
require_relative 'installer_errors'
require 'base64'
require 'openssl'
require 'pathname'
require_relative '../../lib/properties'
require_relative '../../lib/legacy_migration/config_migrator'

class ChorusInstaller
  attr_accessor :destination_path, :data_path, :database_password, :database_user, :install_mode, :legacy_installation_path, :log_stack

  INSTALL_MODES = [:upgrade_existing, :upgrade_legacy, :fresh]

  INSTALL_MODES.each do |mode|
    define_method :"#{mode}?" do
      install_mode == mode
    end
  end

  DEFAULT_PATH = "/usr/local/greenplum-chorus"
  DEFAULT_DATA_PATH = "/data/greenplum-chorus"

  def initialize(options={})
    @installer_home = options[:installer_home]
    @version_detector = options[:version_detector]
    @logger = options[:logger]
    @io = options[:io]
    @log_stack = []
    @install_mode = :fresh
  end

  def prompt(message)
    print "\n#{message} "
  end

  def log(message, &block)
    message = "  " * log_stack.count + message
    @io.log message
    @logger.log message
    if block_given?
      log_stack.push(nil).tap { yield block }.pop
      log "...done."
    end
  end

  def validate_localhost
    unless system("ping -c 1 localhost > /dev/null")
      raise InstallerErrors::InstallAborted, "Could not connect to 'localhost', please set in /etc/hosts"
    end
  end

  def chorus_installation_path
    File.join(@installer_home, 'chorus_installation')
  end

  def determine_postgres_installer
    @postgres_package = get_postgres_build
  end

  def silent?
    @silent
  end

  def get_destination_path
    default_path = ENV['CHORUS_HOME'] || DEFAULT_PATH
    default_path = default_path.sub(/\/current$/, '')

    relative_path = @io.prompt_or_default(:destination_path, default_path)

    @destination_path = File.expand_path(relative_path)
    @version_detector.destination_path = @destination_path
    prompt_for_2_2_upgrade if @version_detector.can_upgrade_2_2?(version)
    prompt_for_legacy_upgrade if @version_detector.can_upgrade_legacy?
    @logger.logfile = File.join(@destination_path, 'install.log')
    validate_path(destination_path)
  end

  def get_data_path
    if !@version_detector.can_upgrade_2_2?(version)
      relative_path = @io.prompt_or_default(:data_path, DEFAULT_DATA_PATH)
      self.data_path = File.expand_path(relative_path)
      log "Data path = #{@data_path}"
      validate_path(data_path)
    end
  end

  def validate_path(path)
    FileUtils.mkdir_p(path)

    unless File.writable?(path)
      raise Errno::EACCES
    end

    true
  rescue Errno::EACCES
    raise InstallerErrors::InstallAborted, "You do not have write permission to #{path}"
  end

  def prompt_for_passphrase
    @io.prompt_or_default(:passphrase, "")
  end

  def prompt_for_legacy_upgrade
    @io.require_confirmation :confirm_legacy_upgrade

    self.install_mode = :upgrade_legacy
    self.legacy_installation_path = destination_path
    prompt_legacy_upgrade_destination
  end

  def prompt_legacy_upgrade_destination
    @destination_path = @io.prompt_until(:legacy_destination_path) { |input| !input.nil? }
    @destination_path = File.expand_path @destination_path
  end

  def prompt_for_2_2_upgrade
    @io.require_confirmation :confirm_upgrade
    self.install_mode = :upgrade_existing
  end

  def get_postgres_build
    input = nil
    input = 3 if is_supported_suse?
    input = 5 if is_supported_mac?

    redhat_version = supported_redhat_version
    input = 1 if redhat_version == '5.5'
    input = 1 if redhat_version == '5.7'
    input = 2 if redhat_version == '6.2'

    if @io.silent? && input.nil?
      raise InstallerErrors::InstallAborted, "Version not supported."
    end

    if input.nil?
      input = @io.prompt_until(:select_os) { |input| (1..4).include?(input.to_i) }.to_i
    end

    case input
      when 1
        "postgres-redhat5.5-9.2.1.tar.gz"
      when 2
        "postgres-redhat6.2-9.2.1.tar.gz"
      when 3
        "postgres-suse11-9.2.1.tar.gz"
      when 5
        "postgres-osx-9.2.1.tar.gz"
      else
        raise InstallerErrors::InstallAborted, "Version not supported."
    end
  end

  def supported_redhat_version
    return nil unless File.exists?('/etc/redhat-release')

    version_string = File.open('/etc/redhat-release').read
    version_string =~ /release (\d\.\d)/
    found_version = $1
    found_version if %w(5.5 5.7 6.2).include?(found_version)
  end

  def is_supported_suse?
    return false unless File.exists?('/etc/SuSE-release')

    File.open('/etc/SuSE-release').readlines.any? do |release|
      release.match(/^VERSION = 11$/)
    end
  end

  def is_supported_mac?
    `uname`.strip == "Darwin"
  end

  def copy_chorus_to_destination
    FileUtils.mkdir_p(release_path)
    FileUtils.cp_r File.join(chorus_installation_path, '.'), release_path, :preserve => true
  end

  def create_shared_structure
    FileUtils.mkdir_p("#{destination_path}/shared")

    if install_mode == :fresh && !(Dir.entries("#{destination_path}/shared") - ['.', '..']).empty?
      raise InstallerErrors::InstallAborted, "#{destination_path}/shared must be empty"
    end

    FileUtils.mkdir_p("#{destination_path}/shared/tmp/pids")
    FileUtils.mkdir_p("#{destination_path}/shared/solr/data")
    FileUtils.mkdir_p("#{destination_path}/shared/log")
    FileUtils.mkdir_p("#{destination_path}/shared/system")
  end

  def copy_config_files
    FileUtils.mkdir_p("#{destination_path}/shared")
    unless File.exists? "#{destination_path}/shared/database.yml"
      FileUtils.cp("#{chorus_installation_path}/packaging/database.yml.example", "#{destination_path}/shared/database.yml")
    end
    FileUtils.cp("#{chorus_installation_path}/config/chorus.properties.example", "#{destination_path}/shared/chorus.properties.example")
    unless File.exists? "#{destination_path}/shared/chorus.properties"
      FileUtils.cp("#{chorus_installation_path}/config/chorus.defaults.properties", "#{destination_path}/shared/chorus.properties")
    end
  end

  def generate_paths_file
    File.open("#{destination_path}/chorus_path.sh", 'w') do |file|
      file.puts "export CHORUS_HOME=#{destination_path}"
      file.puts "export PATH=$PATH:$CHORUS_HOME"
      file.puts "export PGPASSFILE=$CHORUS_HOME/.pgpass"
    end
  end

  def generate_chorus_psql_files
    File.open("#{destination_path}/.pgpass", 'w') do |file|
      file.puts "*:*:chorus:#{database_user}:#{database_password}"
    end
    FileUtils.chmod(0400, "#{destination_path}/.pgpass")

    File.open("#{destination_path}/chorus_psql.sh", 'w') do |file|
      file.puts CHORUS_PSQL
    end
    FileUtils.chmod(0500, "#{destination_path}/chorus_psql.sh")
  end

  def link_services
    FileUtils.ln_sf("#{release_path}/packaging/chorus_control.sh", "#{destination_path}/chorus_control.sh")
  end

  def link_shared_files
    FileUtils.ln_sf("#{destination_path}/shared/chorus.properties", "#{release_path}/config/chorus.properties")
    FileUtils.ln_sf("#{destination_path}/shared/database.yml", "#{release_path}/config/database.yml")
    FileUtils.ln_sf("#{destination_path}/shared/secret.key", "#{release_path}/config/secret.key")
    FileUtils.ln_sf("#{destination_path}/shared/secret.token", "#{release_path}/config/secret.token")

    #Symlink the data paths under shared to the actual data_path directory.  So the app actually
    #goes through two symlinks
    if data_path && File.expand_path("#{data_path}") != File.expand_path("#{destination_path}/shared")
      ['db', 'system', 'solr/data', 'log'].each do |path|
        destination = Pathname.new("#{destination_path}/shared/#{path}")
        source = Pathname.new("#{data_path}/#{path}")
        if(destination.exist? && !destination.symlink?)
          destination.rmdir
        end
        unless(source.exist?)
          source.mkpath
        end
        FileUtils.ln_sf(source.to_s, destination.to_s)
      end
    end

    FileUtils.ln_sf("#{destination_path}/shared/db", "#{release_path}/postgres-db")
    FileUtils.ln_sf("#{destination_path}/shared/tmp", "#{release_path}/tmp")
    FileUtils.ln_sf("#{destination_path}/shared/solr/data", "#{release_path}/solr/data")
    FileUtils.ln_sf("#{destination_path}/shared/log", "#{release_path}/log")
    FileUtils.mkdir_p("#{destination_path}/shared/log/nginx")
    FileUtils.rm_rf("#{release_path}/vendor/nginx/nginx_dist/nginx_data/logs")
    FileUtils.ln_sf("#{destination_path}/shared/log/nginx", "#{release_path}/vendor/nginx/nginx_dist/nginx_data/logs")
    FileUtils.ln_sf("#{destination_path}/shared/system", "#{release_path}/system")
  end

  def create_database_config
    return if upgrade_existing?

    database_config_path = "#{destination_path}/shared/database.yml"
    database_config = YAML.load_file(database_config_path)

    self.database_password = SecureRandom.hex
    self.database_user = database_config['production']['username']

    database_config['production']['password'] = database_password

    File.open(database_config_path, 'w') do |file|
      YAML.dump(database_config, file)
    end
  end

  def setup_database
    if upgrade_existing?
      start_postgres
      log "Running database migrations..." do
        chorus_exec "cd #{release_path} && RAILS_ENV=production bin/rake db:migrate"
        stop_postgres
      end
    else
      log "Initializing database..." do
        File.open("#{release_path}/postgres/pwfile", 'w') do |f|
          f.puts database_password
        end
        FileUtils.chmod(0400, "#{release_path}/postgres/pwfile")
        chorus_exec %Q{#{release_path}/postgres/bin/initdb --locale=en_US.UTF-8 -D #{data_path}/db --auth=md5 --pwfile=#{release_path}/postgres/pwfile --username=#{database_user}}
        start_postgres
        db_commands = "db:create db:migrate"
        db_commands += " db:seed" unless upgrade_legacy?
        log "Running rake #{db_commands}"
        chorus_exec "cd #{release_path} && RAILS_ENV=production bin/rake #{db_commands}"
        stop_postgres
      end
    end
  end

  def link_current_to_release
    File.delete("#{destination_path}/current") if File.exists?("#{destination_path}/current")
    FileUtils.ln_sf("#{release_path}", "#{destination_path}/current")
  end

  def extract_postgres
    chorus_exec("tar xzf #{release_path}/packaging/postgres/#{@postgres_package} -C #{release_path}/")
  end

  def stop_old_install
    return unless upgrade_existing?
    log "Stopping Chorus..." do
      chorus_exec "CHORUS_HOME=#{destination_path}/current #{destination_path}/current/packaging/chorus_control.sh stop"
    end
  end

  def startup
    return unless upgrade_existing?

    log "Starting up Chorus..." do
      chorus_control "start"
    end
  end

  def dump_and_shutdown_legacy
    Dir.chdir legacy_installation_path do
      set_env = "source #{legacy_installation_path}/edc_path.sh"
      log "Shutting down Chorus..." do
        chorus_exec("#{set_env} && bin/edcsvrctl stop; true")
      end
      log "Starting legacy Chorus services (i.e. postgres)..." do
      # run twice because sometimes this fails the first time
        chorus_exec("(#{set_env} && bin/edcsvrctl start || #{set_env} && bin/edcsvrctl start)")
      end
      log "Dumping previous Chorus data..." do
        chorus_exec("cd #{release_path} && PGUSER=edcadmin pg_dump -p 8543 chorus -O -f legacy_database.sql")
      end
      log "Stopping legacy Chorus services (i.e. postgres)..." do
        chorus_exec("#{set_env} && bin/edcsvrctl stop")
      end
    end
  end

  def migrate_legacy_config
    log "Migrating configuration from previous version..." do
      ConfigMigrator.migrate(
          :input_path => File.join(legacy_installation_path, 'chorus-apps', 'applications', 'edcbase', 'config', 'chorus.properties'),
          :output_path => File.join(destination_path, 'shared', 'chorus.properties')
      )
    end
  end

  def migrate_legacy_data
    log "Migrating data from previous version..." do
      log "Loading legacy data into postgres..." do
        chorus_exec("cd #{release_path} && CHORUS_HOME=#{release_path} packaging/chorus_migrate -s legacy_database.sql -w #{legacy_installation_path}/chorus-apps/runtime/data")
      end
    end
  end

  def prompt_for_eula
    puts eula
    @io.require_confirmation :accept_terms
  end

  def install
    prompt_for_eula
    validate_localhost
    get_destination_path
    get_data_path

    determine_postgres_installer

    log "Installing Chorus version #{version} to #{destination_path}"
    log "Copying files into #{destination_path}..." do
      copy_chorus_to_destination
      create_shared_structure
      copy_config_files
      create_database_config

      log "Configuring secret key..."
      configure_secret_key

      log "Configuring secret token..."
      configure_secret_token

      link_shared_files
    end

    log "Extracting postgres..." do
      extract_postgres
    end

    if upgrade_existing?
      log "Shutting down previous Chorus install..." do
        stop_old_install
      end
    elsif upgrade_legacy?
      dump_and_shutdown_legacy
    end

    log "#{upgrade_existing? ? "Updating" : "Creating"} database..." do
      link_services
      generate_paths_file
      generate_chorus_psql_files
      setup_database
    end

    if upgrade_legacy?
      migrate_legacy_config
      migrate_legacy_data
    end

    link_current_to_release

    if is_supported_mac?
      warn_and_change_osx_properties
    end

  rescue InstallerErrors::InstallAborted => e
    puts e.message
    exit 1
  rescue InstallerErrors::AlreadyInstalled => e
    puts e.message
    exit 0
  rescue InstallerErrors::InstallationFailed => e
    log "#{e.class}: #{e.message}"
    raise
  rescue => e
    chorus_control "stop" if upgrade_legacy? rescue # rescue in case chorus_control blows up
    log "#{e.class}: #{e.message}"
    raise InstallerErrors::InstallationFailed, e.message
  end

  def warn_and_change_osx_properties
    log "OS X Users:"
    log "The properties file 'shared/chorus.properties' has had the number of worker_threads and webserver_threads reduced to 5 and the number of database_threads reduced to 15."

    properties_file = File.join(destination_path, "shared", "chorus.properties")
    properties = Properties.load_file(properties_file)
    properties.merge!({"worker_threads" => 5, "webserver_threads" => 5, "database_threads" => 15})
    Properties.dump_file(properties, properties_file)
  end

  def remove_and_restart_previous!
    if upgrade_existing?
      log "Restarting server..."
      chorus_exec "CHORUS_HOME=#{destination_path}/current #{destination_path}/chorus_control.sh start"
    else
      stop_postgres
    end
    log "For Postgres errors check #{destination_path}/shared/db/server.log"
    FileUtils.rm_rf release_path
  end

  def configure_secret_key
    key_file = "#{destination_path}/shared/secret.key"
    return if File.exists?(key_file)

    passphrase = prompt_for_passphrase
    if passphrase.nil? || passphrase.strip.empty?
      passphrase = Random.new.bytes(32)
    end
    # only a subset of openssl is available built-in to jruby, so this is the best we could do without including the full jruby-openssl gem
    secret_key = Base64.strict_encode64(OpenSSL::Digest.new("SHA-256", passphrase).digest)
    File.open(key_file, 'w') do |f|
      f.puts secret_key
    end
  end

  def configure_secret_token
    token_file = "#{destination_path}/shared/secret.token"
    return if File.exists?(token_file)

    File.open(token_file, 'w') do |f|
      f << SecureRandom.hex(64)
    end
  end

  def release_path
    "#{destination_path}/releases/#{version}"
  end

  def eula
    EULA
  end

  private

  def get_input
    input = gets.strip
    input.empty? ? nil : input
  end

  def version
    @version ||= File.read("#{chorus_installation_path}/version_build").strip
  end

  def chorus_exec(command)
    @logger.capture_output("PATH=#{release_path}/postgres/bin:$PATH && #{command}") || raise(InstallerErrors::CommandFailed, command)
  end

  def stop_postgres
    if File.directory? "#{release_path}/postgres"
      log "Stopping postgres..."
      chorus_control "stop postgres"
    end
  end

  def start_postgres
    log "Starting postgres..."
    chorus_control "start postgres"
  end

  def chorus_control(args)
    chorus_exec "CHORUS_HOME=#{release_path} #{release_path}/packaging/chorus_control.sh #{args}"
  end

  CHORUS_PSQL = <<-CHORUS_PSQL
    if [ "$CHORUS_HOME" = "" ]; then
      echo "CHORUS_HOME is not set.  Exiting..."
    else
      $CHORUS_HOME/current/postgres/bin/psql -U postgres_chorus -p 8543 chorus;
    fi
  CHORUS_PSQL

  EULA = <<-EULA
                   SOFTWARE LICENSE AND MAINTENANCE AGREEMENT

           ***  IMPORTANT INFORMATION - PLEASE READ CAREFULLY  ***

This Software contains computer programs and other proprietary material and
information, the use of which is subject to and expressly conditioned upon
acceptance of this Software License and Maintenance Agreement (the "Agreement").

This Agreement is a legally binding document between you (meaning the individual
person or the entity that the individual represents that has obtained the
Software for its internal productive use and not for outright resale) (the
"Customer") and EMC (which means (i) EMC Corporation, if Customer is located in
the United States; (ii) the local EMC sales subsidiary, if Customer is located
in a country in which EMC Corporation has a local sales subsidiary; and (iii)
EMC Information Systems International ("EISI"), if Customer is located outside
the United States and in a country in which EMC Corporation does not have a
local sales subsidiary). Unless EMC agrees otherwise in writing, this Agreement
governs Customer's use of the Software except to the extent all or any portion
of the Software is: (a) the subject of a separate written agreement; or (b)
governed by a third party licensor's terms and conditions. Capitalized terms
have meaning stated in the Agreement.

If Customer does not have a currently enforceable, written and separately signed
software license agreement directly with EMC or the Distributor from whom
Customer obtained this Software, then by clicking on the "Agree" or "Accept" or
similar button at the end of this Agreement, or proceeding with the
installation, downloading, use or reproduction of this Software, or authorizing
any other person to do so, you are representing to EMC that you are (i)
authorized to bind the Customer; and (ii) agreeing on behalf of the Customer
that the terms of this Agreement shall govern the relationship of the parties
with regard to the subject matter in this Agreement and are waiving any rights,
to the maximum extent permitted by applicable law, to any claim anywhere in the
world concerning the enforceability or validity of this Agreement.

If Customer has a currently enforceable, written and separately signed software
license agreement directly with EMC or the Distributor from whom Customer
obtained this Software, then by clicking on the "Agree" or "Accept" or similar
button at the end of this Agreement, or proceeding with the installation,
downloading, use or reproduction of this Software, or authorizing any other
person to do so, you are representing that you are (i) authorized to bind the
Customer; and (ii) agreeing on behalf of the Customer that the terms of such
written, signed agreement shall replace and supersede the terms of this
Agreement and shall govern the relationship of the parties with regard to this
Software, and are waiving any rights, to the maximum extent permitted by
applicable law, to any claim anywhere in the world concerning the enforceability
or validity of such written signed agreement.

If you do not have authority to agree to the terms of this Agreement on behalf
of the Customer, or do not accept the terms of this Agreement on behalf of the
Customer, click on the "Cancel" or "Decline" or other similar button at the end
of this Agreement and/or immediately cease any further attempt to install,
download or use this Software for any purpose, and remove any partial or full
copies made from this Software.

1.  DEFINITIONS.
A.  "Affiliate" means a legal entity that is controlled by, controls, or is
under common "control" of EMC or Customer. "Control" means more than 50% of the
voting power or ownership interests.
B.  "Confidential Information" means and includes the terms of this Agreement,
Software, and Support Tools and all confidential and proprietary information of
EMC or Customer, including without limitation, all business plans, product
plans, financial information, software, designs, and technical, business and
financial data of any nature whatsoever, provided that such information is
marked or designated in writing as "confidential," "proprietary," or any other
similar term or designation. Confidential Information does not include
information that is (i) rightfully in the receiving party's possession without
obligation of confidentiality prior to receipt from the disclosing party, (ii) a
matter of public knowledge through no fault of the receiving party, (iii)
rightfully furnished to the receiving party by a third party without restriction
on disclosure or use; or (iv) independently developed by the receiving party
without use of or reference to the disclosing party's Confidential Information.
C.  "Distributor" means a reseller, distributor, system integrator, service
provider, independent software vendor, value-added reseller, OEM or other
partner that is authorized by EMC to license Software to end users. The term
shall also refer to any third party duly authorized by a Distributor to license
Software to end users.
D.  "Documentation" means the then-current, generally available, written user
manuals and online help and guides for Software provided by EMC.
E.  "Product Notice" means the notice by which EMC informs Customer of product-
specific use rights and restrictions, warranty periods, warranty upgrades and
maintenance (support) terms. Product Notices may be delivered in an EMC quote,
otherwise in writing and/or a posting on the applicable EMC website, currently
located at http://www.emc.com/products/warranty_maintenance/index.jsp. The terms
of the Product Notice in effect as of the date of the EMC quote shall be deemed
incorporated into and made a part of the relevant Customer purchase order. Each
Product Notice is dated and is archived when it is superseded by a newer
version. EMC shall not change any Product Notice retroactively with regard to
any Software or Support Services listed on an EMC quote issued prior to the date
of the applicable Product Notice. At Customer's request, EMC shall without undue
delay provide Customer with a copy of the applicable Product Notice and/or
attach it to the relevant EMC quote.
F.  "Software" means the EMC software product which requires acceptance of this
Agreement, and any copies made by or on behalf of Customer, Software Releases,
and all Documentation for the foregoing.
G.  "Software Release" means any subsequent version of Software provided by EMC
after initial delivery of Software but does not mean a new item of Software.
H.  "Support Services" means the annual service available from EMC or its
designee which provides Software Releases and support services for Software as
set forth in the Product Notice.
I.  "Support Tools" means any hardware, software and other tools and/or
utilities used by EMC to perform diagnostic or remedial activities in connection
with Software including any software or other tools made available by EMC to
Customer to enable Customer to perform various self-maintenance activities.

2.  DELIVERY AND INSTALLATION.
A.  Delivery.  Title and risk of loss to the physical media, if any, which has
been sold to Customer and contains Software shall transfer to Customer upon
EMC's delivery to a carrier at EMC's designated point of shipment ("Delivery").
Unless otherwise agreed, a common carrier shall be specified by EMC. Software
may be provided by (i) Delivery of physical media; or (ii) electronic means
(where available from EMC). If the physical media containing Software has not
been sold (for example - a lease or rental transaction), then risk of loss
thereto transfers at Delivery, but title does not.
B.  Installation and Acceptance.  EMC's obligation, if any, to install Software
as part of the Software's licensing fee, is set forth in the Product Notice.
Acceptance that Software operates in substantial conformity to the Software's
Documentation occurs upon Delivery or electronic availability, as applicable.
Notwithstanding such acceptance, Customer retains all rights and remedies set
forth in Section 4 (WARRANTY AND DISCLAIMER) below.

3.  LICENSE TERMS.
A.  General License Grant.  Subject to Customer's compliance with this
Agreement, the Product Notice, and payment of all license fees, EMC grants to
Customer a nonexclusive and nontransferable (except as otherwise permitted
herein) license (with no right to sublicense) to use (i) Software for Customer's
internal business purposes; and (ii) the Documentation related to Software for
the purpose of supporting Customer's use of Software. Licenses granted to
Customer shall, unless otherwise indicated on the Product Notice or quote from
EMC or Distributor) be perpetual and commence on Delivery of the physical media
or the date Customer is notified of electronic availability, as applicable.
Documentation is licensed solely for purposes of supporting Customer's use of
Software as permitted in this Section. To the extent applicable to Software,
Customer may be required to follow EMC's then current product registration
process, if any, to obtain and input an authorization key or license file.
B.  Licensing Models.  Software is licensed for use only in accordance with the
commercial terms and restrictions of the Software's relevant licensing model,
which are stated in the Product Notice and/or quote from EMC or Distributor. For
example, the licensing model may provide that Software is licensed for use
solely (i) for a certain number of licensing units; (ii) on or in connection
with certain hardware, or a CPU, network or other hardware environment; and/or
(iii) for a specified amount of storage capacity. Microcode, firmware or
operating system software required to enable the hardware with which it is
shipped to perform its basic functions, is licensed for use solely on such
hardware.
C.  License Restrictions.  All Software licenses granted herein are for use of
object code only. Customer is permitted to copy Software as necessary to install
and run it in accordance with the license, but otherwise for back-up purposes
only. Customer may copy Documentation insofar as reasonably necessary in
connection with Customer's authorized internal use of Software. Customer shall
not, without EMC's prior written consent (i) use Software in a service bureau,
application service provider or similar capacity; or (ii) disclose to any third
party the results of any comparative or competitive analyses, benchmark testing
or analyses of Software performed by or on behalf of Customer; (iii) make
available Software in any form to anyone other than Customer's employees or
contractors; or (iv) transfer Software to an Affiliate or a third party.
D.  Software Releases.  Software Releases shall be subject to the license terms
applicable to Software.
E.  Audit Rights.  EMC (including its independent auditors) shall have the right
to audit Customer's usage of Software to confirm compliance with the agreed
terms. Such audit is subject to reasonable advance notice by EMC and shall not
unreasonably interfere with Customer's business activities. Customer will
provide EMC with the support required to perform such audit and will, without
prejudice to other rights of EMC, address any non-compliant situations
identified by the audit by forthwith procuring additional licenses.
F.  Termination.  EMC may terminate licenses for cause, if Customer breaches the
terms governing use of Software and fails to cure within thirty (30) days after
receipt of EMC's written notice thereof. Upon termination of a license, Customer
shall cease all use and return or certify destruction of the applicable Software
(including copies) to EMC.
G.  Reserved Rights.  All rights not expressly granted to Customer are reserved.
In particular, no title to, or ownership of, the Software is transferred to
Customer. Customer shall reproduce and include copyright and other proprietary
notices on and in any copies of the Software. Unless expressly permitted by
applicable mandatory law, Customer shall not modify, enhance, supplement, create
derivative works from, reverse assemble, reverse engineer, decompile or
otherwise reduce to human readable form the Software without EMC's prior written
consent, nor shall Customer permit any third party to do the same.

4.  WARRANTY AND DISCLAIMER.
A.  Software Warranty.  EMC warrants that Software will substantially conform to
the applicable Documentation for such Software and that any physical media
provided by EMC will be free from manufacturing defects in materials and
workmanship until the expiration of the warranty period. EMC does not warrant
that the operation of Software shall be uninterrupted or error free, that all
defects can be corrected, or that Software meets Customer's requirements, except
if expressly warranted by EMC in its quote. Support Services from EMC for
Software are available for separate purchase and the Support Options are
identified at the Product Notice.
B.  Warranty Duration.  Unless otherwise stated on the EMC quote, the warranty
period for Software shall (i) be as set forth at the Product Notice; and (ii)
commence upon Delivery of the media or the date Customer is notified of
electronic availability, as applicable.
C.  Customer Remedies.  EMC's entire liability and Customer's exclusive remedies
under the warranties described in this section shall be for EMC, at its option,
to remedy the non-compliance or to replace the affected Software. If EMC is
unable to effect such within a reasonable time, then EMC shall refund the amount
received by EMC for the Software concerned. All replaced Software contained on
physical media supplied by EMC shall be returned to and become the property of
EMC. EMC shall have no liability hereunder after expiration of the applicable
warranty period. The foregoing shall not void any supplementary remedies made
available to Customer by a Distributor, with respect to which EMC shall have no
liability or obligation.
D.  Warranty Exclusions.  Warranty does not cover problems that arise from (i)
accident or neglect by Customer or any third party; (ii) any third party items
or services with which Software is used or other causes beyond EMC's control;
(iii) installation, operation or use not in accordance with EMC's instructions
or the applicable Documentation; (iv) use in an environment, in a manner or for
a purpose for which Software was not designed; or (v) modification, alteration
or repair by anyone other than EMC or its authorized representatives;. EMC has
no obligation whatsoever for Software installed or used beyond the licensed use,
or whose original identification marks have been altered or removed. Removal or
disablement of remote support capabilities during the warranty period requires
reasonable notice to EMC. Such removal or disablement, or improper use or
failure to use applicable Customer Support Tools shall be subject to a surcharge
in accordance with EMC's then current standard rates.
E.  No Further Warranties.  Except for the warranty set forth herein, and to the
maximum extent permitted by law, EMC (INCLUDING ITS SUPPLIERS) MAKES NO OTHER
EXPRESS OR IMPLIED WARRANTIES, WRITTEN OR ORAL. INSOFAR AS PERMITTED UNDER
APPLICABLE LAW, ALL OTHER WARRANTIES ARE SPECIFICALLY EXCLUDED, INCLUDING
WARRANTIES ARISING BY STATUTE, COURSE OF DEALING OR USAGE OF TRADE.

5.  SUPPORT SERVICES.
A.  Support Services.  If Customer has purchased Support Services for Software
(or its related hardware, if any) directly from EMC, such shall be delivered by
EMC as specified in the applicable Product Notice. If Customer has purchased
maintenance and support from a Distributor, then EMC may provide Support
Services to the extent that the Distributor has contracted with EMC to provide
Customer with Support Services.
B.  Reinstatement of Lapsed Support.  If Support Services expire or are
terminated, and Customer subsequently seeks to reinstate Support Services,
Customer shall pay: (i) the cumulative Support Services fees applicable for the
period during which Support Services lapsed; (ii) the annual support fees for
the then-current current period; and (iii) the then-current reinstatement fee
and/or certification fees, as quoted by EMC or a Distributor.
C.  Support Tools.  EMC may use Support Tools or may make certain Support Tools
available to assist Customer in performing various maintenance or support
related tasks. Customer shall use Support Tools only in accordance with the
terms under which EMC makes such available.
D.  Additional Support Terms.  Unless otherwise indicated in the Product Notice,
Support Services provided by EMC shall consist of (i) using commercially
reasonable efforts to remedy failures of Software to perform substantially in
accordance with EMC's applicable Documentation; (ii) providing English-language
(or where available, local language help line service (via telephone or other
electronic media); and (iii) providing, or enabling Customer to download
Software Releases and Documentation updates made generally available by EMC at
no additional charge to other purchasers of Support Service for the applicable
Software.
E.  Software Releases.  Upon use of a Software Release, Customer shall remove
and make no further use of all prior Software Releases, and protect such prior
Software Releases from disclosure or use by any third party. Customer is
authorized to retain a copy of each Software Release properly obtained by
Customer for Customer's archive purposes and use such as a temporary back-up if
the current Software Release becomes inoperable. Customer shall use and deploy
Software Releases strictly in accordance with terms of the original license for
the Software.
F.  Support Services for Software affected by Change in Hardware Status.  For
Software used on or operated in connection with hardware that ceases to be
covered by Support Services or the EMC hardware warranty, EMC reserves the right
to send Customer written notice that EMC has either chosen to discontinue or
change the price for Support Services for such Software (with such price change
effective as of the date the applicable EMC hardware ceases to be so covered).
If EMC sends a discontinuation notice, or if Customer rejects or does not
respond to the notice of a proposed price change within thirty (30) days after
receipt, Customer will be deemed to have terminated the Support Services for its
convenience.
G.  Support Services Exclusions.  Support Services do not cover problems that
arise from (i) accident or neglect by Customer or any third party; (ii) any
third party items or services with which the Software is used or other causes
beyond EMC's control; (iii) installation, operation or use not in accordance
with EMC's instructions or the applicable Documentation; (iv) use in an
environment, in a manner or for a purpose for which the Software or its related
hardware was not designed; or (v) modification, alteration or repair by anyone
other than EMC or its authorized designees. EMC has no obligation whatsoever for
Software installed or used beyond the licensed use. Removal or disablement of
Software's remote support capabilities during the term of Support Services
requires reasonable notice to EMC. Customer's removal, disablement of remote
support capabilities, or improper use of or failure to use Support Tools made
available to Customer shall subject Customer to a surcharge in accordance with
EMC's then current standard rates.

6.  INDEMNITY.  EMC shall (i) defend Customer against any third party claim that
Software or Support Services infringes a patent or copyright existing in the
country in which EMC is located, the United States of America or the European
Union; and (ii) pay the resulting costs and damages finally awarded against
Customer by a court of competent jurisdiction or the amounts stated in a written
settlement negotiated by EMC. The foregoing obligations are subject to the
following: Customer (a) notifies EMC promptly in writing of such claim; (b)
grants EMC sole control over the defense and settlement thereof; (c) reasonably
cooperates in response to an EMC request for assistance; and (d) is not in
material breach of this Agreement. Should any such Software or Support Service
become, or in EMC's opinion be likely to become, the subject of such a claim,
EMC may, at its option and expense, (1) procure for Customer the right to make
continued use thereof; (2) replace or modify such so that it becomes non-
infringing; (3) request return of the Software and, upon receipt thereof; refund
the price paid by Customer, less straight-line depreciation based on a three (3)
year useful life for Software; or (4) discontinue the Support Service and refund
the portion of any pre-paid Support Service fee that corresponds to the period
of Support Service discontinuation. EMC shall have no liability to the extent
that the alleged infringement arises out of or relates to: (A) the use or
combination of Software or Support Service with third party products or
services; (B) use for a purpose or in a manner for which the Software or Support
Service was not designed; (C) any modification made by any person other than EMC
or its authorized representatives; (D) any modifications to Software or Support
Service made by EMC pursuant to Customer's specific instructions; (E) any
technology owned or licensed by Customer from third parties; or (F) use of any
older version of the Software when use of a newer Software Release made
available to Customer would have avoided the infringement. THIS SECTION STATES
CUSTOMER'S SOLE AND EXCLUSIVE REMEDY AND EMC'S ENTIRE LIABILITY FOR THIRD PARTY
INFRINGEMENT CLAIMS.

7.  LIMITATION OF LIABILITY.
A.  Limitation on Direct Damages.  EXCEPT WITH RESPECT TO CLAIMS ARISING UNDER
SECTION 6 ABOVE, EMC'S TOTAL LIABILITY AND CUSTOMER'S SOLE AND EXCLUSIVE REMEDY
FOR ANY CLAIM OF ANY TYPE WHATSOEVER, ARISING OUT OF SOFTWARE OR SERVICE
PROVIDED HEREUNDER, SHALL BE LIMITED TO PROVEN DIRECT DAMAGES CAUSED BY EMC'S
SOLE NEGLIGENCE IN AN AMOUNT NOT TO EXCEED (i) US$1,000,000, FOR DAMAGE TO REAL
OR TANGIBLE PERSONAL PROPERTY; AND (ii) THE PRICE PAID BY CUSTOMER TO EMC FOR
THE SPECIFIC SERVICE (CALCULATED ON AN ANNUAL BASIS, WHEN APPLICABLE) OR
SOFTWARE FROM WHICH SUCH CLAIM ARISES, FOR DAMAGE OF ANY TYPE NOT IDENTIFIED IN
(i) ABOVE OR OTHERWISE EXCLUDED HEREUNDER.
B.  No Indirect Damages.  EXCEPT WITH RESPECT TO CLAIMS REGARDING VIOLATION OF
EMC'S INTELLECTUAL PROPERTY RIGHTS OR CLAIMS ARISING UNDER SECTION 6 ABOVE,
NEITHER CUSTOMER NOR EMC SHALL HAVE LIABILITY TO THE OTHER FOR ANY SPECIAL,
CONSEQUENTIAL, EXEMPLARY, INCIDENTAL, OR INDIRECT DAMAGES (INCLUDING, BUT NOT
LIMITED TO, LOSS OF PROFITS, REVENUES, DATA AND/OR USE), EVEN IF ADVISED OF THE
POSSIBILITY THEREOF.
C.  Special Exclusion.  IN JURISDICTIONS THAT DO NOT ALLOW LIMITATION OR
EXCLUSION OF CONSEQUENTIAL OR INCIDENTAL DAMAGES, ALL OR A PORTION OF SECTION
7.A AND/OR 7.B ABOVE MAY NOT APPLY.
D.  Regular Back-ups.  As part of its obligation to mitigate damages, Customer
shall take reasonable data back-up measures. In particular, Customer shall back-
up the relevant data before EMC performs any remedial, upgrade, new Software
Release or other works on Customer's production systems. To the extent EMC's
liability for loss of data is not anyway excluded under this Agreement, EMC
shall in case of data losses only be liable for the typical effort to recover
the data which would have accrued if Customer had appropriately backed up its
data.
E.  Limitation Period.  Unless otherwise required by applicable law, the
limitation period for claims for damages shall be eighteen (18) months after the
cause of action accrues, unless statutory law provides for a shorter limitation
period.
F.  Suppliers.  The foregoing limitations shall also apply in favor of EMC's
suppliers.

8.  EVALUATION AND LOANED SOFTWARE.
A.  This Agreement shall also apply to (i) "Evaluation Software" (meaning the
copy of Software which contains this Agreement, including any copies made by or
on behalf of Customer, and all Documentation for the foregoing, which are
licensed for a limited duration for the specific purpose of evaluation prior to
making a final decision on procurement; and (ii) "Loaned Software" (meaning the
copy of Software which contains this Agreement, including any copies made by or
on behalf of Customer, and all Documentation for the foregoing, which are
licensed for a limited duration directly  to Customer for a limited period of
time at no charge), subject to the following:
B.  The particular Evaluation or Loaned Software, period of use, Installation
Site and other transaction-specific conditions shall be as mutually agreed
between EMC and Customer and recorded in the form of an evaluation or loan
schedule.
C.  Notwithstanding any deviating terms in this Agreement, all licenses for
Evaluation and Loaned Software expire at the end of the evaluation or loan
period.
D.  Customer shall return Evaluation and Loaned Software at the end of the
evaluation or loan period or when sooner terminated by EMC for convenience by
giving thirty (30) days' written notice, whichever occurs first. Customer shall
bear the risk of loss and damage for return of physical media, if any, and de-
installation.
E.  Customer may use Evaluation and Loaned Software free of charge, but, in the
case of Evaluation Software, solely for the purpose of evaluation and not in a
production environment.
F.  Without prejudice to any other limitations on EMC's liability set forth in
this Agreement (which shall also apply to Evaluation and Loaned Software),
Evaluation and Loaned Software are provided "AS IS" and any warranty or damage
claims against EMC in connection with Evaluation and Loaned Software are hereby
excluded, except in the event of fraud or willful misconduct of EMC.
G.  Unless otherwise specifically agreed in writing by EMC, EMC does not provide
maintenance or support for any Evaluation Software. CUSTOMER RECOGNIZES THAT
EVALUATION SOFTWARE MAY HAVE DEFECTS OR DEFICIENCIES WHICH CANNOT OR MAY NOT BE
CORRECTED BY EMC. EMC shall have no liability to Customer for any action (or any
prior related claims) brought by or against Customer alleging that Customer's
sale, use or other disposition of any Evaluation Software infringes any patent,
copyright, trade secret or other intellectual property right. In event of such
an action, EMC retains the right to terminate this Agreement and take possession
of the Evaluation Software. THIS SECTION STATES EMC'S ENTIRE LIABILITY WITH
RESPECT TO ALLEGED INFRINGEMENTS OF INTELLECTUAL PROPERTY RIGHTS BY EVALUATION
SOFTWARE OR ANY PART OF IT OR ITS OPERATION.

9.  CONFIDENTIALITY.  Each party shall (i) use Confidential Information of the
other party only for the purposes of exercising rights or performing obligations
in connection with this Agreement; and (ii) use at least reasonable care to
protect from disclosure to any third parties any Confidential Information
disclosed by the other party for a period commencing upon the date of disclosure
until three (3) years thereafter, except with respect to Customer data to which
EMC may have access in connection with the provision of Services, which shall
remain Confidential Information until one of the exceptions stated in the above
definition of Confidential Information applies. Notwithstanding the foregoing,
either party may disclose Confidential Information (a) to an Affiliate for the
purpose of fulfilling its obligations or exercising its rights hereunder as long
as such Affiliate complies with the foregoing; and (b) if required by law
provided the receiving party has given the disclosing party prompt notice.

10.  GOVERNMENT REGULATIONS AND EXPORT CONTROL.  Software and the technology
included therein provided under this Agreement are subject to governmental
restrictions on (i) exports from the U.S.; (ii) exports from other countries in
which such Software and technology included therein may be produced or located;
(iii) disclosures of technology to foreign persons; (iv) exports from abroad of
derivative products thereof; and (v) the importation and/or use of such Software
and technology included therein outside of the United States or other countries
(collectively, "Export Laws"). Customer shall comply with all Export Laws and
EMC export policies to the extent such policies are made available to Customer
by EMC. Diversion contrary to U.S. law or other Export Laws is expressly
prohibited.

11.  TERMINATION.  Customer may terminate this Agreement for its convenience
upon thirty (30) days' notice to EMC. Either Customer or EMC may terminate this
Agreement upon written notice due to the other party's material breach of the
terms governing use of the Software; provided that such breach is not cured
within thirty (30) days after the provision of written notice to the breaching
party specifying the nature of such breach. Upon termination of this Agreement,
Customer shall cease all use and return or certify destruction of the applicable
Software (including copies) to EMC. Any provision that by its nature or context
is intended to survive any termination or expiration, including but not limited
to provisions relating to payment of outstanding fees, confidentiality and
liability, shall so survive.

12.  MISCELLANEOUS.
A.  References.  EMC may identify Customer for reference purposes unless and
until Customer expressly objects in writing.
B.  Notices and Language.  Any notices permitted or required under this
Agreement shall be in writing, and shall be deemed given when delivered (i) in
person, (ii) by overnight courier, upon written confirmation of receipt, (iii)
by certified or registered mail, with proof of delivery, (iv) by facsimile
transmission with confirmation of receipt, or (v) by email, with confirmation of
receipt (except for routine business communications issued by EMC, which shall
not require confirmation from Customer). Notices shall be sent to the address,
facsimile number or email address set forth below, or at such other address,
facsimile number or email address as provided to the other party in writing.
Notices shall be sent to: EMC Corporation, 176 South Street, Hopkinton, MA
01748. Fax for legal notices: 508.293.7780. Email for legal notices:
legalnotices@emc.com. The parties agree that this Agreement has been written in
the English language, that the English language version shall govern and that
all notices shall be in the English language.
C.  Entire Agreement.  This Agreement (i) is the complete statement of the
agreement of the parties with regard to the subject matter hereof; and (ii) may
be modified only by a writing signed by both parties. All terms of any purchase
order or similar document provided by Customer, including but not limited to any
pre-printed terms thereon and any terms that are inconsistent or conflict with
this Agreement, shall be null and void and of no legal force or effect.
D.  Force Majeure.  Except for the payment of fees, if any, due EMC from
Customer, neither party shall be liable under this Agreement because of a
failure or delay in performing its obligations hereunder on account of any force
majeure event, such as strikes, riots, insurrection, terrorism, fires, natural
disasters, acts of God, war, governmental action, or any other cause which is
beyond the reasonable control of such party.
E.  Assignment.  Customer shall not assign this Agreement or any right or
delegate any performance without EMC's prior written consent, which consent
shall not be unreasonably withheld. Customer shall promptly notify EMC, and EMC
may terminate this Agreement on thirty days' notice, if Customer merges with or
is acquired by a third party or otherwise undergoes a change of control.
F.  Governing Law.  This Agreement is governed by: (i) the laws of the
Commonwealth of Massachusetts when EMC means EMC Corporation; (ii) the laws of
the applicable country in which the applicable EMC subsidiary is registered to
do business when EMC means the local EMC subsidiary, and (iii) the laws of
Ireland when EMC means EISI. In each case, the applicability of laws shall
exclude any conflict of law rules. The U.N. Convention on Contracts for the
International Sale of Goods shall not apply. In the event of a dispute
concerning this Agreement, Customer consents to the sole and exclusive personal
jurisdiction of the courts of competency in the location where EMC is domiciled.
G.  Waiver.  No waiver shall be deemed a waiver of any prior or subsequent
default hereunder. If any part of this Agreement is held unenforceable, the
validity of the remaining provisions shall not be affected.
H.  Partial Invalidity.  If any part of this Agreement, a purchase order or an
EMC quote is held unenforceable, the validity of the remaining provisions shall
not be affected.

13.  COUNTRY SPECIFIC TERMS.
A.  Canada.  The terms in this subsection A apply only when EMC means the EMC
sales subsidiary located in Canada (currently EMC Corporation of Canada):
    1.  Section 2.A (Delivery).  The second sentence is deleted in its
entirety and replaced with: "Title and risk of loss to physical media, if any,
transfers to Customer at the time and place that the media clears Canadian
Customs."
    2.  Section 3.A (General License Grant).  The last two sentences are
deleted and replaced with: "Licenses granted shall commence on the date the
physical media, if any, clears Canadian Customs or electronic availability of
such Software to Customer." Documentation is licensed solely for purposes of
supporting Customer's use of the Software as permitted in this Section.
    3.  Section 12 (MISCELLANEOUS).  Add the following as new subsection I:
        I.  The parties have required that this Agreement be drawn up in
English and have also agreed that all notices or other documents required by or
contemplated in this Agreement be written in English.
         Les parties ont requis que cette convention soit redigee en anglais
et ont egalement convenu que tout avis ou autre document exige aux termes des
presentes ou decoulant de l'une quelconque de ses dispositions sera prepare en
anglais.

B.  United Kingdom.  The terms in this subsection B apply only when EMC means
the EMC sales subsidiary located in the United Kingdom (currently EMC Computer
Systems (UK) Limited):
      1.  Section 4.D (Warranty Exclusions).  The entire section is deleted and
replaced with:
        D.  Warranty Exclusions.  Except as expressly stated in the
applicable warranty set forth in this Agreement, EMC (including its suppliers)
provides Software "AS IS" and makes no other express or implied warranties,
written or oral, and ALL OTHER WARRANTIES AND CONDITIONS (SAVE FOR THE
WARRANTIES AND CONDITIONS IMPLIED BY SECTION 12 OF THE SALE OF GOODS ACT 1979)
ARE SPECIFICALLY EXCLUDED TO THE FULLEST EXTENT PERMITTED BY LAW, INCLUDING, BUT
NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE, TITLE, AND ANY WARRANTY ARISING BY STATUTE, OPERATION OF
LAW, COURSE OF DEALING OR PERFORMANCE, OR USAGE OF TRADE.
    2.  Section 7 (LIMITATION OF LIABILITY).  This Section is deleted in its
entirety and replaced with:
         7.  LIMITATION OF LIABILITY AND PRESERVATION OF DATA.
         A.  The entire aggregate liability of EMC (including its
suppliers) under or in connection with the supply of the Software or Service,
whether in tort (including negligence), for breach of contract,
misrepresentation or otherwise, is limited in respect of each event or a series
of events: (i) to the amounts actually paid by Customer for the Software or
Services which give rise to such liability during the twelve (12) month period
immediately preceding the date of the cause of action giving rise to such claim;
or (ii) Great British Pounds Sterling one million (1,000,000), whichever is the
greater amount. In no event shall EMC (including its suppliers) or Customer be
liable to the other or any other person or entity for loss of profits, loss of
revenue, loss of use or any indirect, special, incidental, consequential or
exemplary damages arising out of or in connection with this Agreement, the
license of the Software or the provision of Services, and the use, performance,
receipt or disposition of such Software or Services, even if such party has been
advised of the possibility of such damages or losses. Nothing in this Agreement
shall operate to exclude or restrict EMC's liability for: (a) death or personal
injury resulting from negligence; (b) breach of obligations arising from section
12 of the Sale of Goods Act 1979; or (c) fraud.
        B.  CUSTOMER OBLIGATIONS IN RESPECT OF PRESERVATION OF DATA.
During the Term of the Agreement, the Customer shall:
          1) from a point in time prior to the point of failure, (i)
make full and/or incremental backups of data which allow recovery in an
application consistent form, and (ii) store such back-ups at an off-site
location sufficiently distant to avoid being impacted by the event(s) (e.g.
including but not limited to flood, fire, power loss, denial of access or air
crash) and affect the availability of data at the impacted site;
          2) have adequate processes and procedures in place to restore
data back to a point in time and prior to point of failure, and in the event of
real or perceived data loss, provide the skills/backup and outage windows to
restore the data in question;
          3) use anti-virus software, regularly install updates across
all data which is accessible across the network, and protect all storage arrays
against power surges and unplanned power outages with Uninterruptible Power
Supplies; and
          4) ensure that all operating system, firmware, system utility
(e.g. but not limited to, volume management, cluster management and backup) and
patch levels are kept to EMC recommended versions and that any proposed changes
thereto shall be communicated to EMC in a timely fashion.
    3.  Section 12 (MISCELLANEOUS).  Add the following as new subsection I:
           I.  Each of the parties acknowledges and agrees that in entering
into this Agreement, it does not rely on, and shall have no remedy in respect
of, any statement, representation, warranty or understanding (whether
negligently or innocently made) of any person (whether party to this Agreement
or not) other than as expressly set out in this Agreement as a warranty. The
only remedy available to Customer for a breach of the warranties shall be for
breach of contract under the terms of this Agreement. Nothing in Section 7 shall
however operate to limit or exclude any liability for fraud. No term of this
Agreement shall be enforceable under the Contracts (Rights of Third Parties) Act
1999 by a person that is not a party to this Agreement. If any part of this
Agreement is held unenforceable, the validity of the remaining provisions shall
not be affected.

C.  Ireland.  The terms in this subsection C apply only when EMC means the EMC
sales subsidiary located in Ireland (currently EMC Information Systems
International:
    1. Section 4.D (Warranty Exclusions). The entire section is deleted and
replaced with:
        D.  Warranty Exclusions.  Except as expressly stated in the
applicable warranty set forth in this Agreement and the applicable exhibits, EMC
including its suppliers) and makes no warranties, and ALL WARRANTIES, TERMS AND
CONDITIONS, WHETHER ORAL OR WRITTENPLIED BY LAW, CUSTOMER OR
OTHERWISE, INCLUDING, BUT NOT LIMITED TO, ANY WARRANTIES, TERMS AND CONDITIONS,
OF FITNESS FOR PURPOSE, DESCRIPTION, AND QUALITY ARE HEREBY EXCLUDED TO THE
MAXIMUM EXTENT PERMITTED UNDER APPLICABLE LAW.
    2.  Section 7 (LIMITATION OF LIABILITY). This section is deleted in its
entirety and replaced with the following:
        7.  LIMITATION OF LIABILITY.
            A. EMC does not exclude or limit its liability to the
Customer for death or personal injury, or, breach of obligations implied by
Section 12 of the Sale of Goods Act, 1893, as amended by the Sale of Goods and
Supply of Services Act, 1980, or, due to the fraud or fraudulent
misrepresentation of EMC, its employees or agents.
            B. Subject always to subsection 7.A, the liability of EMC
(including its suppliers) to the Customer under or in connection with an order,
whether arising from negligent error or omission, breach of contract, or
otherwise ("Defaults") shall be: (i) the aggregate liability of EMC for all
Defaults resulting in direct loss of or damage to the tangible property of the
Customer shall be limited to damages which shall not exceed the greater of two
hundred per cent (200%) of the applicable price paid and/or payable for the
Software or Service, or one million euros (1,000,000); or (ii) the aggregate
liability of EMC for all Defaults, other than those governed by subsection
7.B(i) shall be limited to damages which shall not exceed (a) in respect of the
Software, the greater of one hundred and fifty per cent (150%) of the applicable
price paid and/or payable or five hundred thousand euro (500,000); or (b) in
respect of the services, if any, the greater of one hundred and fifty per cent
(150%) of the applicable charges paid and/or payable or five hundred thousand
euro (500,000).
           C. In no event shall EMC (including its suppliers) be liable
to Customer for (i) loss of profits, loss of business, loss of revenue, loss of
use, wasted management time, cost of substitute services or facilities, loss of
goodwill or anticipated savings, loss of or loss of use of any software or data;
and/or (ii) indirect, consequential or special loss or damage; and/or (iii)
damages, costs and/or expenses due to third party claims; and/or (iv) loss or
damage due to the Customer's failure to comply with obligations under this
Agreement, failure to do back-ups of data or any other matter under the control
of the Customer. For the purposes of this Section 7, the term "loss" shall
include a partial loss, as well as a complete or total loss.
           D. The parties expressly agree that should any limitation or
provision contained in this Section 7 be held to be invalid under any applicable
statute or rule of law, it shall to that extent be deemed omitted, but if any
party thereby becomes liable for loss or damage which would otherwise have been
excluded such liability shall be subject to the other limitations and provisions
set out in this Section 7.
           E. The parties expressly agree that any order for specific
performance made in connection with this Agreement in respect of EMC shall be
subject to the financial limitations set out in sub-section 7.B.
           F. The parties expressly agree that the provisions of Section
6 (INDEMNITY) shall not be subject to the limitations and exclusions of
liability set out in this Section 7.
           G. CUSTOMER OBLIGATIONS IN RESPECT OF PRESERVATION OF DATA.
During the Term of the Agreement the Customer shall:
            1)  from a point in time prior to the point of failure,
(i) make full and/or incremental backups of data which allow recovery in an
application consistent form, and (ii) store such back-ups at an off-site
location sufficiently distant to avoid being impacted by the event(s) (e.g.
including but not limited to flood, fire, power loss, denial of access or air
crash) and affect the availability of data at the impacted site;
            2)  have adequate processes and procedures in place to
restore data back to a point in time and prior to point of failure, and in the
event of real or perceived data loss, provide the skills/backup and outage
windows to restore the data in question;
            3)  use anti-virus software, regularly install updates
across all data which is accessible across the network, and protect all storage
arrays against power surges and unplanned power outages with Uninterruptible
Power Supplies; and
            4)  ensure that all operating system, firmware, system
utility (e.g. but not limited to, volume management, cluster management and
backup) and patch levels are kept to EMC recommended versions and that any
proposed changes thereto shall be communicated to EMC in a timely fashion.
    3.  Section 7.D (Limitation Period).  This Section is deleted in its
entirety and replaced with the following as a totally separate section:
       WAIVER OF RIGHT TO BRING ACTIONS: The Customer waives the right to bring
any claim arising out of or in connection with this Agreement more than twenty-
four (24) months after the date of the cause of action giving rise to such
claim.

D.  European Union. The terms in this subsection D apply only when EMC means an
EMC sales subsidiary located in the European Union:
    1.  Section 3.A (General License Grant).  The following is added at the
end of this section:
         Customer shall not, and Customer shall not permit any third party
to, modify, enhance, supplement, create derivative works from, reverse assemble,
reverse engineer, reverse compile or otherwise reduce to human readable form the
Software without EMC's prior written consent, except to the extent that local,
mandatory law grants Customer the right to decompile such Software in order to
obtain information necessary to render such interoperable with other software.
In such event, Customer shall first inform EMC of its intention and request EMC
to provide Customer with the necessary information. EMC may impose reasonable
conditions on the provision of the requested information, including the payment
of a reasonable fee.

E.  Australia. The terms in this subsection E apply only when EMC means the EMC
sales subsidiary located in Australia (currently EMC Global Holdings Company
(Australian Branch) ABN 86 669 010 6895:
    1.  Section 7 (LIMITATION OF LIABILITY). This section is deleted in its
entirety and replaced with the following:
        7.  LIMITATION OF LIABILITY.
               A. Limitation on Direct Damages. EXCEPT WITH RESPECT TO
CLAIMS ARISING UNDER SECTION 6 OF THIS AGREEMENT, EMC'S AND ITS SUPPLIERS' TOTAL
LIABILITY AND CUSTOMER'S SOLE AND EXCLUSIVE REMEDY FOR ANY CLAIM OF ANY TYPE
WHATSOEVER, ARISING OUT OF SOFTWARE OR SERVICE PROVIDED HEREUNDER, SHALL BE
LIMITED TO PROVEN DIRECT DAMAGES CAUSED BY EMC'S SOLE NEGLIGENCE IN AN AMOUNT
NOT TO EXCEED (i) AUD$2,000,000, FOR DAMAGE TO REAL OR TANGIBLE PERSONAL
PROPERTY; AND (ii) THE PRICE PAID BY CUSTOMER TO EMC FOR THE SPECIFIC SERVICE
(CALCULATED ON AN ANNUAL BASIS, WHEN APPLICABLE) OR SOFTWARE FROM WHICH SUCH
CLAIM ARISES, FOR DAMAGE OF ANY TYPE NOT IDENTIFIED IN (i) ABOVE OR OTHERWISE
EXCLUDED HEREUNDER.
               B. No Indirect Damages.  EXCEPT WITH RESPECT TO CLAIMS
REGARDING VIOLATION OF EMC'S INTELLECTUAL PROPERTY RIGHTS OR CLAIMS ARISING
UNDER SECTION 6 ABOVE, NEITHER CUSTOMER NOR EMC (INCLUDING EMC'S SUPPLIERS)
SHALL (a) HAVE LIABILITY TO THE OTHER FOR ANY SPECIAL, CONSEQUENTIAL, EXEMPLARY,
INCIDENTAL, OR INDIRECT DAMAGES (INCLUDING, BUT NOT LIMITED TO, LOSS OF PROFITS,
REVENUES, DATA AND/OR USE), EVEN IF ADVISED OF THE POSSIBILITY THEREOF; AND (b)
BRING ANY CLAIM BASED ON SOFTWARE OR SERVICE PROVIDED HEREUNDER MORE THAN
EIGHTEEN (18) MONTHS AFTER THE CAUSE OF ACTION ACCRUES.
               C. Trade Practices Legislation: EMC's liability under any
statutory right or any condition or warranty, including any implied by any State
Fair Trading Act or the Trade Practices Act, 1974 (Cth) is, to the maximum
extent permitted by law, excluded. To the extent that such liability cannot be
excluded, EMC's liability is limited at the option of EMC to: (a) in the case of
Software, any one or more of the following: (i) the replacement thereof or the
supply of its equivalent; (ii) the repair thereof; (iii) the payment of the cost
of replacement thereof or of acquiring its equivalent; or (iv) the payment of
the cost of having such repaired, and (b) in the case of any Services performed
by EMC under or in connection with this Agreement: (i) the supply of those
Services again; or (ii) the payment of the cost of having those Services
supplied again.

F.  New Zealand - The terms in this subsection F apply only when EMC means the
EMC sales subsidiary located in New Zealand (currently EMC CORPORATION (NEW
ZEALAND BRANCH) AKOS. 1188883:
    1.  Section 7 (LIMITATION OF LIABILITY). This section is deleted in its
entirety and replaced with the following:
        7.  LIMITATION OF LIABILITY.
            A. Limitation on Direct Damages. EXCEPT WITH RESPECT TO
CLAIMS ARISING UNDER SECTION 6 OF THIS AGREEMENT, EMC'S AND ITS SUPPLIERS' TOTAL
LIABILITY AND CUSTOMER'S SOLE AND EXCLUSIVE REMEDY FOR ANY CLAIM OF ANY TYPE
WHATSOEVER, ARISING OUT OF SOFTWARE OR SERVICE PROVIDED HEREUNDER, SHALL BE
LIMITED TO PROVEN DIRECT DAMAGES CAUSED BY EMC'S SOLE NEGLIGENCE IN AN AMOUNT
NOT TO EXCEED (i) NZ$2,000,000, FOR DAMAGE TO REAL OR TANGIBLE PERSONAL
PROPERTY; AND (ii) THE PRICE PAID BY CUSTOMER TO EMC FOR THE SPECIFIC SERVICE
(CALCULATED ON AN ANNUAL BASIS, WHEN APPLICABLE) OR SOFTWARE FROM WHICH SUCH
CLAIM ARISES, FOR DAMAGE OF ANY TYPE NOT IDENTIFIED IN (i) ABOVE OR OTHERWISE
EXCLUDED HEREUNDER.
            B. No Indirect Damages. EXCEPT WITH RESPECT TO CLAIMS
REGARDING VIOLATION OF EMC'S INTELLECTUAL PROPERTY RIGHTS OR CLAIMS ARISING
UNDER SECTION 6 ABOVE, NEITHER CUSTOMER NOR EMC (INCLUDING EMC'S SUPPLIERS)
SHALL (a) HAVE LIABILITY TO THE OTHER FOR ANY SPECIAL, CONSEQUENTIAL, EXEMPLARY,
INCIDENTAL, OR INDIRECT DAMAGES (INCLUDING, BUT NOT LIMITED TO, LOSS OF PROFITS,
REVENUES, DATA AND/OR USE), EVEN IF ADVISED OF THE POSSIBILITY THEREOF; AND (b)
BRING ANY CLAIM BASED ON SOFTWARE OR SERVICE PROVIDED HEREUNDER MORE THAN
EIGHTEEN (18) MONTHS AFTER THE CAUSE OF ACTION ACCRUES.
            C. Fair Trading Legislation. EMC's liability under any
statutory right or any condition or warranty, including any implied by the Fair
Trading Act 1986 or Consumer Guarantees Act 1993 ("FTA") or any similar law is,
to the maximum extent permitted by law, excluded. To the extent that such
liability cannot be excluded, EMC's liability is limited at the option of EMC
to: (a) in the case of any Software, any one or more of the following: (i) the
replacement thereof or the supply of its equivalent; (ii) the repair thereof;
(iii) the payment of the cost of replacement thereof or of acquiring its
equivalent; or (iv) the payment of the cost of having such repaired, and (b) in
the case of any Services performed by EMC under or in connection with this
Agreement: (i) the supply of those Services again; or (ii) the payment of the
cost of having those Services supplied again.


CLCK WRP Rev 20090813

  EULA
end
