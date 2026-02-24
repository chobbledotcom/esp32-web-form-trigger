class Submission < ApplicationRecord
  belongs_to :form
  belongs_to :device
  belongs_to :user, optional: true

  validates :name, presence: true, if: -> { form.enable_name }
  validates :email_address, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}, if: -> { form.enable_email_address }
  validates :phone, presence: true, if: -> { form.enable_phone }
  validates :address, presence: true, if: -> { form.enable_address }
  validates :postcode, presence: true, if: -> { form.enable_postcode }

  scope :unclaimed, -> { where(credit_claimed: false) }
  scope :for_device, ->(device_id) { where(device_id: device_id) }
  scope :recent, ->(seconds) { where("created_at > ?", seconds.seconds.ago) }

  def mark_as_claimed!
    update_column(:credit_claimed, true)
  end

  def reset_credit!
    update_column(:credit_claimed, false)
  end

  def mark_as_emailed!
    update_columns(email_status: "sent", emailed_at: Time.current)
  end

  def mark_as_failed!(error_message = nil)
    update_columns(
      email_status: "failed",
      failure_reason: error_message
    )
  end
end
