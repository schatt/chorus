require_relative 'jdbc_overrides/teradata_overrides'
require_relative 'jdbc_overrides/sqlserver_overrides'
require_relative 'jdbc_overrides/mariadb_overrides'
require_relative 'jdbc_overrides/mysql_overrides'
require_relative 'jdbc_overrides/hive2_overrides'

module JdbcOverrides
  #module OverrideTemplate
  #  module ConnectionOverrides
  #  end
  #
  #  module CancelableQueryOverrides
  #  end
  #
  #  module DatasetOverrides
  #  end
  #
  #  module VisualizationOverrides
  #  end
  #end

  # For hive2, mariadb, sqlserver, teradata, ... there are some deviations from standard jdbc behavior.
  # This module consolidates the overrides necessary to handle them.
  def overrides_by_db_url(db_url)
    case db_url
      when /jdbc:teradata:/ then JdbcOverrides::Teradata
      when /jdbc:sqlserver:/ then JdbcOverrides::SqlServer
      when /jdbc:mariadb:/ then JdbcOverrides::Mariadb
      when /jdbc:mysql:/ then JdbcOverrides::MySQL
      when /jdbc:hive2:/ then JdbcOverrides::Hive2
      else nil
    end
  end
end