class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_login

  def trigger
    form = Form.find_by!(code: params[:code])
    device = Device.find(params[:device_id])

    submission = form.submissions.build(device: device)
    submission.save!(validate: false)

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
