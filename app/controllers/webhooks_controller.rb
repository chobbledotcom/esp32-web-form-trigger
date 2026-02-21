class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_login

  def trigger
    form = Form.find_by!(code: params[:code])
    device = Device.find(params[:device_id])

    score = extract_score
    if score.nil?
      Rails.logger.warn("[Webhook] No score found in request for form=#{form.code} device=#{device.id}")
      head :unprocessable_entity
      return
    end

    if score.to_i != 100
      Rails.logger.warn("[Webhook] Score validation failed: score=#{score} (expected 100) for form=#{form.code} device=#{device.id}")
      head :unprocessable_entity
      return
    end

    submission = form.submissions.build(device: device)
    submission.save!(validate: false)

    Rails.logger.info("[Webhook] Score=100, submission created for form=#{form.code} device=#{device.id}")
    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

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
