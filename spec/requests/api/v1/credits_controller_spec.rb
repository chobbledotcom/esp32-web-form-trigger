require "rails_helper"

RSpec.describe "API V1 Credits", type: :request do
  # Shared device and form setup
  let(:device) { Device.create!(name: "Test Device", location: "Test Location") }

  # Default form attributes with reasonable defaults
  let(:default_form_attributes) do
    {
      name: "Test Form",
      token_validity_seconds: 3600, # 1 hour validity by default
      button_text: "Submit",
      enable_email_address: false,
      enable_name: false,
      enable_phone: false,
      enable_address: false,
      enable_postcode: false
    }
  end

  # Helper methods for test setup
  def create_form(attributes = {})
    Form.create!(default_form_attributes.merge(attributes))
  end

  def create_submission(form, device, attributes = {})
    defaults = {name: "Test User", credit_claimed: false}
    Submission.create!(defaults.merge(attributes).merge(device: device, form: form))
  end

  def create_submission_with_age(form, device, age, attributes = {})
    submission = create_submission(form, device, attributes)
    submission.update_column(:created_at, age.ago)
    submission
  end

  def json_response
    JSON.parse(response.body)
  end

  # Shared examples for common behaviors
  shared_examples "updates device timestamp" do
    it "updates the device's last_heard_from timestamp" do
      expect { subject }.to change { device.reload.last_heard_from }
      expect(device.reload.last_heard_from).to be_within(1.minute).of(Time.current)
    end
  end

  shared_examples "device not found error" do
    it "returns a not found error" do
      subject
      expect(response).to have_http_status(:not_found)
      expect(json_response).to include("error" => "Device not found")
    end
  end

  describe "POST /api/v1/credits/claim" do
    # Define subject for the request
    subject { post "/api/v1/credits/claim", params: {device_id: device_id} }
    let(:device_id) { device.id }

    context "with an invalid device_id" do
      let(:device_id) { "nonexistent" }
      include_examples "device not found error"
    end

    context "with a valid device" do
      include_examples "updates device timestamp"

      context "with always_allow_credit_claim set to true" do
        before { device.update!(always_allow_credit_claim: true) }

        it "returns success without changing any credits" do
          # Setup a form, submission, and free credit
          form = create_form
          device.forms << form
          submission = create_submission(form, device)
          device.update!(free_credit: true)

          # Verify nothing changes when credit is claimed
          expect { subject }.not_to change { submission.reload.credit_claimed }
          expect { subject }.not_to change { device.reload.free_credit }

          # Verify response
          expect(response).to have_http_status(:success)
          expect(json_response).to include(
            "success" => true,
            "message" => "Credit claimed successfully",
            "source" => "always_allow"
          )
        end
      end

      context "with submission credits" do
        let!(:form) { create_form }

        before { device.forms << form }

        it "claims the submission credit and returns success" do
          submission = create_submission(form, device)

          expect { subject }.to change { submission.reload.credit_claimed }.from(false).to(true)

          expect(response).to have_http_status(:success)
          expect(json_response).to include(
            "success" => true,
            "message" => "Credit claimed successfully",
            "source" => "submission"
          )
        end

        context "with token validity checks" do
          it "only claims submissions within the token validity period" do
            # Create a form with short validity period
            short_form = create_form(name: "Short Validity Form", token_validity_seconds: 30)
            device.forms << short_form

            # Create submissions with different ages
            old_submission = create_submission_with_age(short_form, device, 1.hour, name: "Old User")
            recent_submission = create_submission(short_form, device, name: "Recent User")

            subject

            # Recent submission should be claimed, old one should not
            expect(recent_submission.reload.credit_claimed).to eq(true)
            expect(old_submission.reload.credit_claimed).to eq(false)
            expect(json_response["source"]).to eq("submission")
          end

          it "respects each form's token validity period" do
            # Create forms with different validity periods
            short_form = create_form(name: "Short Form", token_validity_seconds: 30)
            long_form = create_form(name: "Long Form", token_validity_seconds: 86400) # 1 day

            # Associate both with device
            device.forms << short_form
            device.forms << long_form

            # Create submissions for both forms, both 1 hour old
            old_short = create_submission_with_age(short_form, device, 1.hour, name: "Old Short")
            old_long = create_submission_with_age(long_form, device, 1.hour, name: "Old Long")

            subject

            # Long form submission should be claimed (within 24h validity)
            # Short form submission should not be claimed (outside 30s validity)
            expect(old_long.reload.credit_claimed).to eq(true)
            expect(old_short.reload.credit_claimed).to eq(false)
          end
        end

        context "with multiple sources of credits" do
          it "claims the submission credit first" do
            # Set up both submission and free credit
            device.update!(free_credit: true)
            submission1 = create_submission(form, device, name: "User 1")
            submission2 = create_submission(form, device, name: "User 2")

            subject

            # First submission should be claimed first
            expect(submission1.reload.credit_claimed).to eq(true)

            # Free credit and second submission should not be claimed yet
            expect(device.reload.free_credit).to eq(true)
            expect(submission2.reload.credit_claimed).to eq(false)
            expect(json_response["source"]).to eq("submission")
          end

          it "claims submission credits before free credits" do
            # Set up both submission and free credit
            device.update!(free_credit: true)
            submission1 = create_submission(form, device, name: "User 1")
            submission2 = create_submission(form, device, name: "User 2")

            # Claim first submission
            post "/api/v1/credits/claim", params: {device_id: device.id}
            expect(submission1.reload.credit_claimed).to eq(true)

            # Claim second submission
            post "/api/v1/credits/claim", params: {device_id: device.id}
            expect(submission2.reload.credit_claimed).to eq(true)

            # Free credit should still not be claimed
            expect(device.reload.free_credit).to eq(true)

            # Claim free credit last
            post "/api/v1/credits/claim", params: {device_id: device.id}
            expect(device.reload.free_credit).to eq(false)
            expect(json_response["source"]).to eq("free_credit")
          end
        end
      end

      context "with a free credit available" do
        before { device.update!(free_credit: true) }

        it "claims the free credit and returns success" do
          expect { subject }.to change { device.reload.free_credit }.from(true).to(false)

          expect(response).to have_http_status(:success)
          expect(json_response).to include(
            "success" => true,
            "message" => "Free credit claimed successfully",
            "source" => "free_credit"
          )
        end
      end

      context "with no credits available" do
        before { device.update!(free_credit: false) }

        it "returns an error" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json_response).to include(
            "success" => false,
            "message" => "No credits available"
          )
        end
      end

      context "when credits are exhausted" do
        it "returns error after all credits are claimed" do
          # Set up a form and submission with free credit
          form = create_form
          device.forms << form
          device.update!(free_credit: true)
          submission = create_submission(form, device)

          # Claim submission credit
          post "/api/v1/credits/claim", params: {device_id: device.id}
          expect(submission.reload.credit_claimed).to eq(true)

          # Claim free credit
          post "/api/v1/credits/claim", params: {device_id: device.id}
          expect(device.reload.free_credit).to eq(false)

          # Attempt to claim when no credits are available
          post "/api/v1/credits/claim", params: {device_id: device.id}
          expect(response).to have_http_status(:not_found)
          expect(json_response).to include(
            "success" => false,
            "message" => "No credits available"
          )
        end
      end
    end
  end

  describe "GET /api/v1/credits/check" do
    subject { get "/api/v1/credits/check", params: {device_id: device_id} }
    let(:device_id) { device.id }

    context "with an invalid device_id" do
      let(:device_id) { "nonexistent" }
      include_examples "device not found error"
    end

    context "with a valid device_id" do
      include_examples "updates device timestamp"

      it "returns the correct credit information with no credits" do
        subject

        expect(response).to have_http_status(:success)
        expect(json_response).to include(
          "device_id" => device.id,
          "credits_available" => 0,
          "submission_credits" => 0,
          "free_credit_available" => false,
          "always_allow_credit_claim" => false
        )
      end

      it "counts unclaimed submissions correctly" do
        # Create form and submissions
        form = create_form
        device.forms << form

        # Create two submissions, one claimed and one unclaimed
        create_submission(form, device, credit_claimed: true, name: "User 1")
        create_submission(form, device, credit_claimed: false, name: "User 2")

        subject

        expect(json_response).to include(
          "submission_credits" => 1,
          "credits_available" => 1
        )
      end

      it "includes free credit in the total" do
        device.update!(free_credit: true)

        subject

        expect(json_response).to include(
          "free_credit_available" => true,
          "credits_available" => 1
        )
      end

      it "combines submission and free credits" do
        # Set up form, submission, and free credit
        form = create_form
        device.forms << form
        device.update!(free_credit: true)
        create_submission(form, device)

        subject

        expect(json_response).to include(
          "submission_credits" => 1,
          "free_credit_available" => true,
          "credits_available" => 2
        )
      end

      it "returns always 1 credit when always_allow_credit_claim is true" do
        device.update!(always_allow_credit_claim: true)

        subject

        expect(json_response).to include(
          "always_allow_credit_claim" => true,
          "credits_available" => 1
        )
      end
    end
  end
end
