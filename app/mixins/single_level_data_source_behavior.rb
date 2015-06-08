module SingleLevelDataSourceBehavior
  extend ActiveSupport::Concern

  included do
    after_destroy :enqueue_destroy_schemas
  end

  def refresh_databases(options={})
    refresh_schemas options
  end

  def refresh_schemas(options={})
    schema_permissions = update_schemas(options)
    update_permissions(schema_permissions)
    schemas.map(&:name)
  end

  private

  def update_schemas(options)
    begin
      schema_permissions = {}
      accounts.each do |account|
        begin
          schemas = Schema.refresh(account, self, options.reverse_merge(:refresh_all => true))
          schemas.each do |schema|
            schema_permissions[schema.id] ||= []
            schema_permissions[schema.id] << account.id
          end
        rescue connection_class.error_class => e
          Chorus.log_debug "Could not refresh schemas for data source account #{account.id}: #{e.error_type} #{e.message} #{e.backtrace.to_s}"
        end
      end
    rescue => e
      Chorus.log_error "Error refreshing Schema #{e.message}"
    end
    schema_permissions
  end

  def update_permissions(schema_permissions)
    schema_permissions.each do |schema_id, account_ids|
      schema = schemas.find(schema_id)
      if schema.data_source_account_ids.sort != account_ids.sort
        schema.data_source_account_ids = account_ids
        schema.save!
        SolrIndexer.SolrQC.enqueue_if_not_queued("#{schema.class.name}.reindex_datasets", schema.id)
      end
    end
  end

end