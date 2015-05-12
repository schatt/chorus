require 'clockwork'
require 'queue_classic'

module QC
  def self.log(data)
    Scrolls.log({ :timestamp => Time.current.to_s, :lib => :queue_classic, :level => :debug}.merge(data))
  end
end

module Clockwork
  configure do |config|
    logger = Logger.new(STDOUT)
    logger.formatter = proc do |severity, datetime, progname, msg|
      datetime_format = datetime.strftime "%Y-%m-%d %H:%M:%S"
      "[#{datetime_format}] #{msg}\n"
    end
    config[:logger] = logger
  end
end