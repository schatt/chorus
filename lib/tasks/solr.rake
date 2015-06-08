require 'sunspot'

namespace :services do
  namespace :solr do
    task :run do
      path = File.expand_path(File.dirname(__FILE__) + '/../../config') + '/sunspot.yml'
      log_path = File.expand_path(File.dirname(__FILE__) + '/../../log')

      rails_environment = ENV['RAILS_ENV'] || 'development'

      solr_config = nil
      File.open(path) do |file|
        yaml_contents = ERB.new(file.read).result
        solr_config = YAML.load(yaml_contents)[rails_environment]
      end

      server = Sunspot::Solr::Server.new
      server.bind_address = 'localhost'
      server.port = solr_config['solr']['port']
      server.log_level = solr_config['solr']['log_level']
      server.solr_data_dir = (Rails.root + "solr/data/#{rails_environment}/").to_s
      server.solr_home = Rails.root.join('solr').to_s
      server.log_file = log_path + "/solr-#{rails_environment}.log"

      server.run
    end
  end
end

namespace :enqueue do
  task :reindex => :environment do
    SolrIndexer.SolrQC.enqueue_if_not_queued('SolrIndexer.reindex', ['all'])
  end

  task :refresh_and_reindex => :environment do
    SolrIndexer.SolrQC.enqueue_if_not_queued('SolrIndexer.refresh_and_reindex', ['all'])
  end
end
