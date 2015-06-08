# Properties relating to toggling/configuration of startup of a service using chorus.properties
chorus_home = File.expand_path(File.dirname(__FILE__) + '/../')
require File.join(chorus_home, 'app', 'models', 'chorus_config')

chorus_config = ChorusConfig.new(chorus_home)

puts "export INDEXER_DISABLED=1" if chorus_config['indexer'] && chorus_config['indexer']['enabled'] == false
