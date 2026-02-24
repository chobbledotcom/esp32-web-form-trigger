require "rails_helper"

RSpec.describe Api::V1::CreditsController, type: :controller do
  # Helper methods for test setup
  def create_device(attributes = {})
    defaults = {name: "Test Device", location: "Test Location"}
    Device.create!(defaults.merge(attributes))
  end

  def create_form(attributes = {})
    defaults = {name: "Test Form", button_text: "Submit", token_validity_seconds: 120}
    Form.create!(defaults.merge(attributes))
  end

  def create_submission(device, form, attributes = {})
    defaults = {
      name: "Test User",
      email_address: "test@example.com",
      credit_claimed: false
    }
    Submission.create!(defaults.merge(attributes).merge(device: device, form: form))
  end

  def create_submission_with_age(device, form, age, attributes = {})
    attributes[:created_at] = age.ago
    create_submission(device, form, attributes)
  end

  # Shared setup
  let!(:device) { create_device }
  let!(:form) { create_form }

  before do
    # Associate device with form
    device.forms << form
  end

  describe "POST #claim" do
    subject { post :claim, params: {device_id: device.id}, format: :json }

    context "with unclaimed submissions" do
      it "claims a recent submission" do
        submission = create_submission_with_age(device, form, 30.seconds)

        subject

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["source"]).to eq "submission"
        expect(submission.reload.credit_claimed).to be true
      end

      it "claims old submissions regardless of age" do
        submission = create_submission_with_age(device, form, 180.seconds)

        subject

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["source"]).to eq "submission"
        expect(submission.reload.credit_claimed).to be true
      end

      it "claims oldest submission first" do
        submission1 = create_submission_with_age(device, form, 200.seconds, name: "User 1", email_address: "user1@example.com")
        submission2 = create_submission_with_age(device, form, 100.seconds, name: "User 2", email_address: "user2@example.com")

        subject

        expect(response).to have_http_status(:success)
        expect(submission1.reload.credit_claimed).to be true
        expect(submission2.reload.credit_claimed).to be false
      end
    end

    context "with no unclaimed submissions and no free credit" do
      it "returns not found" do
        device.update!(free_credit: false)

        subject

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
      end
    end
  end
end
