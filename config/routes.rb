Chorus::Application.routes.draw do
  resource :sessions, :only => [:create, :destroy, :show]
  resource :config, :only => [:show], :controller => 'configurations'
  resource :license, :only => [:show]
  resources :activities, :only => [:index, :show], :controller => 'events'
  resources :taggings, :only => [:create, :index]
  resources :tags, :only => [:index, :destroy, :update]
  resources :users, :only => [:index, :show, :create, :update, :destroy] do
    collection do
      get :ldap
    end
    resource :image, :only => [:show, :create], :controller => :user_images
    resource :dashboard_config, :only => [:show, :create], :controller => :user_dashboards
  end

  resources :hdfs_data_sources, :only => [:create, :index, :show, :update, :destroy] do
    scope :module => 'hdfs' do
      resources :files, :only => [:show, :index] do
        resource :statistics, :only => :show
        resource :imports, :only => :create
      end
    end
  end

  resources :hdfs_params, :only => [:index], :controller => 'hdfs/params'

  resources :hdfs_datasets, :only => [:create, :update, :destroy]

  resources :data_sources, :only => [:index, :show, :create, :update, :destroy] do
    resources :databases, :only => [:index], :controller => 'databases'

    scope :module => 'data_sources' do
      resource :account, :only => [:show, :create, :update, :destroy]
      resource :owner, :only => [:update]
      resource :sharing, :only => [:create, :destroy], :controller => 'sharing'
      resource :workspace_detail, :only => [:show]
      resources :members, :only => [:index, :create, :update, :destroy]
      resources :schemas, :only => [:index]
    end

    # Remove this once Alpine uses alpine/credentials directly
    get 'credentials' => 'alpine/credentials#show'
  end

  resources :gnip_data_sources, :except => [:new, :edit] do
    resources :imports, :only => [:create], :controller => 'gnip_data_source_imports'
  end

  resources :jdbc_hive_data_sources, :except => [:new, :edit] do
  end

  resources :databases, :only => [:show] do
    resources :schemas, :only => [:index], :controller => 'database_schemas'
  end

  resources :schemas, :only => [:show] do
    resources :datasets, :only => [:index]
    resources :functions, :only => [:index]
    resources :imports, :only => :create, :controller => 'schemas/imports'
  end

  resources :tables, :only => [] do
    resource :analyze, :only => [:create], :controller => 'analyze'
  end

  resources :datasets, :only => [:show] do
    resources :columns, :only => [:index]
    resources :previews, :only => [:create, :destroy], :constraints => {:id => /.*/}
    resources :visualizations, :only => [:create, :destroy]
    resource :statistics, :only => :show
    resource :download, :only => :show, :controller => 'dataset_downloads'
    resource :importability, :only => [:show]
    collection do
      post :preview_sql, :controller => 'previews'
    end
  end

  resources :chorus_views, :only => [:create, :update, :destroy] do
    member do
      post :convert
      post :duplicate
    end
  end

  resource :imports, :only => :update, :controller => 'dataset_imports'

  resources :workspaces, :only => [:index, :create, :show, :update, :destroy] do
    resources :members, :only => [:index, :create]
    resource :image, :only => [:create, :show], :controller => :workspace_images
    resource :sandbox, :only => [:create]
    resources :workfiles, :only => [:create, :index] do
      collection do
        delete :index, action: :destroy_multiple
      end
    end
    resources :jobs, :only => [:index, :create, :show, :update, :destroy] do
      resources :job_tasks, :only => [:create, :update, :destroy]
    end
    resources :milestones, :only => [:index, :create, :update, :destroy]
    resource :quickstart, :only => [:destroy], :controller => 'workspace_quickstart'
    resources :imports, :only => [:create], :controller => 'workspaces/imports'

    resources :datasets, :only => [:index, :create, :show, :destroy], :controller => 'workspace_datasets' do
      collection do
        delete :index, action: :destroy_multiple
      end
      resources :imports, :only => [:index], :controller => 'dataset_imports'
      resources :tableau_workbooks, :only => :create
    end
    resource :search, :only => [:show], :controller => 'workspace_search'

    resources :external_tables, :only => [:create]
    resources :csv, :only => [:create], :controller => 'workspace_csv' do
      resources :imports, :only => [:create], :controller => 'workspaces/csv_imports'
    end
  end

  resource :uploads, :only => [:create]

  resources :jobs, :only => [] do
    resources :job_results, :only => [:show]
    member do
      post :run
      post :stop
    end
  end

  resources :job_tasks, :only => [:update]

  resources :workfiles, :only => [:show, :destroy, :update] do
    resource :draft, :only => [:show, :update, :create, :destroy], :controller => :workfile_draft
    resources :versions, :only => [:update, :create, :show, :index, :destroy], :controller => 'workfile_versions'
    resource :copy, :only => [:create], :controller => 'workfile_copy'
    resource :download, :only => [:show], :controller => 'workfile_download'
    resources :executions, :only => [:create, :destroy], :controller => 'workfile_executions'
    resources :results, :only => [:create], :controller => 'workfile_results'
    member do
      post 'run'
      post 'stop'
    end
  end

  resources :workfile_versions, :only => [] do
    resource :image, :only => [:show], :controller => 'workfile_version_images'
  end

  resources :notes, :only => [:create, :update, :destroy] do
    resources :attachments, :only => [:create, :show], :controller => 'attachments'
  end

  resources :comments, :only => [:create, :show, :destroy]

  resources :notifications, :only => [:index, :destroy] do
    collection do
      put :read
    end
  end

  resources :attachments, :only => [] do
    resource :download, :only => [:show], :controller => 'attachment_downloads'
  end

  resources :insights, :only => [:index, :create, :destroy] do
    collection do
      post :publish
      post :unpublish
    end
  end

  resource :search, :only => [:show], :controller => 'search' do
    get :type_ahead
    get :workspaces
    member do
      post :reindex
    end
  end

  namespace :kaggle do
    resources :users, :only => [:index]
    resources :messages, :only => [:create]
  end

  namespace :alpine do
    resources :data_sources, :only => [] do
      resource :credentials, :only => [:show]
    end

    resources :datasets, :only => [:index]
  end

  resource :status, :only => [:show], :controller => 'status'
  resource :dashboards, :only => [:show] do
    scope :module => 'dashboards' do
      resource :recent_workfiles, :only => [:create], :controller => 'recent_workfiles'
      resource :project_card_list, :only => [:create, :show], :controller => 'project_card_list'
    end
  end

  namespace :import_console do
    match '/' => 'imports#index'
    resources :imports, :only => :index
  end

  post 'download_chart', :controller => 'image_downloads'

  post 'download_data', :controller => 'data_downloads'

  match '/' => 'root#index'
  match 'VERSION' => 'configurations#version'

end
