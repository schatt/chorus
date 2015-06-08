require_relative '../../app/models/chorus_config'

Chorus::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  config.log_level = :debug

  config.cache_store = :file_store, Rails.root.to_s + "/tmp/cache/chorus"

  # Show full error reports and disable caching
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  #config.active_record.auto_explain_threshold_in_seconds = 0.5

  # Do not compress assets
#  config.assets.compress = false
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = false

  # Give paperclip path to ImageMagick tools
  Paperclip.options[:command_path] = "/usr/local/bin/"

  # Only turn it on if you really need concurrent requests
  #config.allow_concurrency = true
  #config.threadsafe!

  if ChorusConfig.instance['mail.enabled']
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = { :address => 'localhost', :port => 1025 }
    ActionMailer::Base.default ChorusConfig.instance.mail_configuration
  else
    config.action_mailer.perform_deliveries = false
  end
end
