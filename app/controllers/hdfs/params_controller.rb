require 'hadoop_conf'

class Hdfs::ParamsController < ApplicationController
  def index
    # Must provide a host and a port
    if !params[:host] || !params[:port]
      render_error("Invalid host or port")
      return
    end

    # Use the hadoop_conf gem to retrieve the config
    t = HadoopConfig.new({
      :server => params[:host],
      :port => params[:port],
      :timeout => 10
    })

    # Fetch and parse properties from hadoop host
    t.fetch

    # Matches parameters as exist in rules.default.yml in hadoopconf_gem.
    # Or be specified in the hadoop_config_fetch_rules.yml file present in config/
    custom_rules = ChorusConfig.instance.custom_hadoop_config_rules
    props = custom_rules.nil? ? t.properties : t.properties(custom_rules)

    # HadoopConfig.errors is an ActiveModel::Errors object
    if t.errors.empty?
      render :json => {
          :response => {
              :params => props
          }
      }, :status => :ok
    else
      render_error(t.errors.full_messages[0])
    end
  end

  private

  def render_error(msg)
    render json: {
        :errors => {
            :params => msg
        }
    }, status: :unprocessable_entity
  end
end
