require 'spec_helper'
require 'job_scheduler'

describe JobScheduler do
  let(:job_scheduler) { JobScheduler.new }
  describe "InstanceStatus.check" do
    it "runs every Chorus::Application.config.chorus['instance_poll_interval_minutes'] minutes" do
      job_scheduler.job_named('InstanceStatus.check').period.should == Chorus::Application.config.chorus['instance_poll_interval_minutes'].minutes
    end

    it "enqueues the 'InstanceStatus.check' job in QC" do
      mock(QC).enqueue("InstanceStatus.check")
      job_scheduler.job_named('InstanceStatus.check').run(Time.now)
    end
  end

  describe "CsvFile.delete_old_files!" do
    it "runs every Chorus::Application.config.chorus['delete_unimported_csv_files_interval_hours'] hours" do
      job_scheduler.job_named('CsvFile.delete_old_files!').period.should == Chorus::Application.config.chorus['delete_unimported_csv_files_interval_hours'].hours
    end

    it "enqueues the 'CsvFile.delete_old_files!' job in QC" do
      mock(QC).enqueue("CsvFile.delete_old_files!")
      job_scheduler.job_named('CsvFile.delete_old_files!').run(Time.now)
    end
  end

  describe "JobScheduler.run" do
    it "builds a JobScheduler and then runs it starts the clockwork" do
      built = false
      any_instance_of(JobScheduler) do |js|
        mock(js).run
        built = true
      end
      JobScheduler.run
      built.should be_true
    end
  end
end

module Clockwork
  class Event
    attr_reader :period
  end
end