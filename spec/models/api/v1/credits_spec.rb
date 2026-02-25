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

    context "with submission within token_validity_seconds" do
      it "claims the submission if it's within token validity period" do
        # Create a recent submission (30s old, within 120s validity)
        submission = create_submission_with_age(device, form, 30.seconds)

        subject

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["source"]).to eq "submission"

        # Check that submission was claimed
        expect(submission.reload.credit_claimed).to be true
      end

      it "does not claim a submission outside token validity period" do
        # Create an older submission that's outside the validity period
        submission = create_submission_with_age(device, form, 180.seconds) # Outside 120s validity

        # Set free credit to false to test fallback behavior
        device.update!(free_credit: false)

        subject

        # Should fail since submission is too old and no free credit
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false

        # Check that submission was not claimed
        expect(submission.reload.credit_claimed).to be false
      end
    end

    context "with different token_validity_seconds for multiple forms" do
      let!(:form2) { create_form(name: "Test Form 2", token_validity_seconds: 300) }

      before do
        device.forms << form2
      end

      it "respects each form's token_validity_seconds setting" do
        # Create submissions for both forms, both 200s old
        # First is too old for form1 (120s validity)
        # Second is still valid for form2 (300s validity)
        submission1 = create_submission_with_age(device, form, 200.seconds, name: "User 1", email_address: "user1@example.com")
        submission2 = create_submission_with_age(device, form2, 200.seconds, name: "User 2", email_address: "user2@example.com")

        subject

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["source"]).to eq "submission"

        # First submission should not be claimed (too old)
        expect(submission1.reload.credit_claimed).to be false
        # Second submission should be claimed (within validity period)
        expect(submission2.reload.credit_claimed).to be true
      end
    end
  end
end
