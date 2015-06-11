class WorkfileDownloadController < ApplicationController
  include FileDownloadHelper

  def show
    authorize! :show, workfile.workspace

    if workfile.has_draft(current_user)
      send_draft
    else
      send_version(params[:version_id])
    end
  end

  private

  def send_draft
    last_version = workfile.latest_workfile_version

    # This line is necessary. If you don't change the last modified
    # header the server will respond with a 304 and the filename
    # will not get updated
    headers['Last-Modified'] = Time.now.httpdate

    draft = workfile.drafts.find_by_owner_id(current_user.id)
    send_data draft.content,
              :disposition => 'attachment',
              :type => last_version.contents_content_type,
              :filename => filename_for_download(workfile.file_name)
  end

  def send_version(version_id)
    download_workfile = nil
    if version_id
      download_workfile = workfile.versions.find(version_id)
    else
      download_workfile = workfile.latest_workfile_version
    end

    send_file download_workfile.contents.path,
              :disposition => 'attachment',
              :type => download_workfile.contents_content_type,
              :filename => filename_for_download(workfile.file_name)
    ActiveRecord::Base.connection.close
  end

  def workfile
    @workfile ||= Workfile.find(params[:workfile_id])
  end
end