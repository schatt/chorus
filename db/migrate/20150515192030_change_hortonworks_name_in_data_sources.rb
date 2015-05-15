class ChangeHortonworksNameInDataSources < ActiveRecord::Migration
  class HdfsDataSource < ActiveRecord::Base; end
  class DataSource < ActiveRecord::Base; end

  def up
    DataSource.
        where(:hive_hadoop_version => 'Hortonworks HDP 2.1').
        update_all(:hive_hadoop_version => 'Hortonworks HDP 2');
    HdfsDataSource.
        where(:hdfs_version => 'Hortonworks HDP 2.1').
        update_all(:hdfs_version => 'Hortonworks HDP 2');
  end

  def down
    DataSource.
        where(:hive_hadoop_version => 'Hortonworks HDP 2').
        update_all(:hive_hadoop_version => 'Hortonworks HDP 2.1');
    HdfsDataSource.
        where(:hdfs_version => 'Hortonworks HDP 2').
        update_all(:hdfs_version => 'Hortonworks HDP 2.1');
  end
end
