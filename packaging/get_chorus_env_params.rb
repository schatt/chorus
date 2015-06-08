script_dir = File.expand_path(File.dirname(__FILE__))

# Exports seem to cause non-exported bash variables declared before the export to go away
load "#{script_dir}/get_newrelic_options.rb"

load "#{script_dir}/get_chorus_startup_properties.rb"

print 'POSTGRES_PORT="'
load "#{script_dir}/get_postgres_port.rb"
puts '"'

print 'SOLR_PORT="'
load "#{script_dir}/get_solr_port.rb"
puts '"'

print 'CHORUS_JAVA_OPTIONS="'
load "#{script_dir}/get_full_java_options.rb"
puts '"'

print 'CHORUS_JAVA_OPTIONS_WITHOUT_XMS="'
load "#{script_dir}/get_java_options_without_xms.rb"
puts '"'

print 'JRUBY_OPTS="'
load "#{script_dir}/get_jruby_options.rb"
puts '"'
