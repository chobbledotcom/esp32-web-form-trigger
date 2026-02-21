class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_login

  def trigger
    form = Form.find_by!(code: params[:code])
    device = Device.find(params[:device_id])

    score = extract_score
    if score.nil?
      Rails.logger.warn("[Webhook] No score found in request for form=#{form.code} device=#{device.id}")
      notify_webhook_received("No score found", form: form, device: device)
      head :ok
      return
    end

    if score.to_i != 100
      Rails.logger.warn("[Webhook] Score validation failed: score=#{score} (expected 100) for form=#{form.code} device=#{device.id}")
      notify_webhook_received("Score validation failed (score=#{score}, expected 100)", form: form, device: device)
      head :ok
      return
    end

    submission = form.submissions.build(device: device)
    submission.save!(validate: false)

    Rails.logger.info("[Webhook] Score=100, submission created for form=#{form.code} device=#{device.id}")
    notify_webhook_received("Submission created (score=#{score})", form: form, device: device)
    head :ok
  rescue ActiveRecord::RecordNotFound => e
    notify_webhook_received("Record not found: #{e.message}")
    head :ok
  end

  private

  def notify_webhook_received(status, form: nil, device: nil)
    details = {
      status: status,
      form_code: form&.code,
      device_id: device&.id,
      request_params: request.request_parameters
    }

    message = "Webhook received: #{status}\n\n#{JSON.pretty_generate(details)}"
    NtfyService.notify(message)
  rescue => e
    Rails.logger.error("[Webhook] Failed to send ntfy notification: #{e.message}")
  end

  def extract_score
    raw = params[:rawRequest]
    return nil unless raw.present?

    data = JSON.parse(raw)

    # Find all q{N}_score keys and pick the highest numbered one (last question)
    score_keys = data.keys.select { |k| k.match?(/\Aq\d+_score\z/) }
    return nil if score_keys.empty?

    last_score_key = score_keys.max_by { |k| k.match(/\Aq(\d+)_score\z/)[1].to_i }
    data[last_score_key]
  rescue JSON::ParserError => e
    Rails.logger.warn("[Webhook] Failed to parse rawRequest JSON: #{e.message}")
    nil
  end
end
