module JdbcOverrides
  module MySQL
    module ConnectionOverrides
      def schemas
        with_connection do |connection|
          ss = []
          connection.process_metadata(:getCatalogs) do |h|
            ss << h[:TABLE_CAT] unless @schema_blacklist.include?(h[:TABLE_CAT])
          end
          ss
        end
      end

      def metadata_for_dataset(dataset_name)
        column_count = with_connection do |connection|
          columns_enum(connection, dataset_name).count
        end
        {:column_count => column_count}
      end

      def column_info(dataset_name, setup_sql)
        with_connection do |connection|
          columns_enum(connection, dataset_name).map do |col|
            { :attname => col[:COLUMN_NAME], :format_type => col[:TYPE_NAME] }
          end
        end
      end

      def datasets(options={})
        res = []
        name_matcher = Regexp.compile(Regexp.escape(options[:name_filter]), Regexp::IGNORECASE) if options[:name_filter]
        count = 0
        metadata_get_tables(JDBC_TYPES[:datasets], options.merge(:schema => schema_name)) do |h|
          break if options[:limit] && count >= options[:limit]
          unless name_matcher && name_matcher !~ h[:TABLE_NAME]
            count += 1
            res << {:name => h[:TABLE_NAME], :type => table_type?(h[:TABLE_TYPE])}
          end
        end
        res
      end

      def object_exists?(types, name)
        return false unless name
        ts = []
        metadata_get_tables(types, :schema => schema_name, :table_name => name) do |h|
          ts << h[:TABLE_NAME]
        end
        ts.include? name
      end

      private

      def columns_enum(connection, dataset_name)
        connection.to_enum(:process_metadata, :getColumns, schema_name, nil, dataset_name, nil)
      end

      def metadata_get_tables(types, opts, &block)
        with_connection do |connection|
          connection.process_metadata(:getTables, opts[:schema], nil, opts[:table_name], types.to_java(:string), &block)
        end
      end

      # TODO: this is copy-paste from JdbcConnection so we can override datasets
      JDBC_TYPES = {
          :tables => %w(TABLE),
          :views => %w(VIEW),
          :datasets => %w(TABLE VIEW)
      }
    end

    module CancelableQueryOverrides
    end

    module DatasetOverrides
    end

    def self.VisualizationOverrides
      return Visualization::MySQL
    end
  end
end
