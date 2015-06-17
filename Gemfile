source 'https://rubygems.org'

gem 'rails', '3.2.18'

gem 'will_paginate'
gem 'net-ldap', '0.11',    :require => false
gem 'paperclip', '3.0.4'
gem 'cocaine', '0.2.1' # cocaine is a paperclip dependency but new versions of cocaine cause trouble. remove this line after upgrading paperclip.
gem 'queue_classic', :github => 'Chorus/queue_classic'
gem 'clockwork',     :require => false
gem 'allowy'
gem 'sunspot_rails', '~> 2.0.0'
gem 'jetpack', :github => 'Chorus/jetpack', :branch => '6c9253195b+chorus', :require => false
gem 'nokogiri'
gem 'sequel', '~> 4.0', :require => 'sequel/no_core_ext'
gem 'attr_encrypted' #if you load attr_encrypted before sequel, it blows up saying 'sequel::model' is undefined
gem 'chorusgnip', :github => 'Chorus/gnip'
gem 'hadoopconf_gem', :github => 'Chorus/chorus-hadoop-conf', :ref => 'ce0d34dde0f5f4dd372af6406fafd9c5b2baac5f'
gem 'logger-syslog'
gem 'newrelic_rpm'
gem 'premailer-rails'
gem 'messengerjs-rails'
gem 'codemirror-rails', '3.23'
gem 'honor_codes', '~> 0.1.0'
# Gem to generate JSON data output using Rails View
gem 'jbuilder'
# Gem that allows you to call view renders from anywhere (model, lib, rake, etc.)
gem 'render_anywhere'


platform :jruby do
  gem 'jruby-openssl', :require => false
  gem 'activerecord-jdbcpostgresql-adapter', '1.3.7'
end

group :assets do
  gem 'sass-rails'
  gem 'compass-rails'
  gem 'handlebars_assets'
  gem 'therubyrhino'
  gem 'uglifier'
  gem 'yui-compressor', '0.12.0'
  gem 'turbo-sprockets-rails3'
  gem 'jquery-rails', '2.1.4'
end

group :integration do
  gem 'capybara', "~> 2.0.0", :require => false
  gem 'headless'
  gem 'capybara-screenshot'
end

group :test, :integration, :packaging, :ci_jasmine, :ci_legacy, :ci_next do
  gem 'rr', :require => false
  gem 'fuubar'
  gem 'factory_girl'
  gem 'shoulda-matchers'
  gem 'rspec-rails'
  gem 'journey'
  gem 'timecop'
  gem 'hashie'
  gem 'vcr', '~> 2.3.0'
  gem 'fakefs',              :require => false
  gem 'chunky_png'
  gem 'database_cleaner',    :require => false
  gem 'poltergeist'
end

group :development, :test, :integration, :packaging, :ci_jasmine, :ci_legacy, :ci_next do
  gem 'foreman', '>= 0.62',      :require => false
  gem 'rake',                    :require => false
  gem 'rspec', '2.14.1',                :require => 'rspec/core/rake_task'
  gem 'jasmine', :github => 'pivotal/jasmine-gem'
  gem 'jasmine-core', :github => 'pivotal/jasmine'
  gem 'sunspot_matchers'
  gem 'fixture_builder'
  gem 'ci_reporter', '>= 1.8.2'
  gem 'faker'
  gem 'fakeweb'
  gem 'quiet_assets'
  gem 'sunspot_solr', :github => 'taktsoft/sunspot', :ref => '78717a33894271d012682dbe8902458badb0ca63' # https://github.com/sunspot/sunspot/pull/267
  gem 'backbone_fixtures_rails', :github => 'charleshansen/backbone_fixtures_rails'
  gem 'rspec_api_documentation', :github => 'Chorus/rspec_api_documentation', :require => false
  gem 'pry' # Drop in to an extended Rails console by creating a 'binding.pry' breakpoint
  gem 'pry-nav' # Adds debugger functionality to Pry
  gem 'ladle'
end

group :development do
  # gem 'tabcmd_gem', :path => "~/alpine/chorus-tableau" # otherwise is set in Gemfile-packaging
  # gem 'hadoopconf_gem', :path => "~/alpine/chorus-hadoop-conf"
  gem 'license_finder', '~> 0.8.1', :require => false
  gem 'mizuno'
  gem 'bullet'
  gem 'capistrano', '2.15.5'
end
