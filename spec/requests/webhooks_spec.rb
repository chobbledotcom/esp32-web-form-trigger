require "rails_helper"

RSpec.describe "Webhooks", type: :request do
  let!(:device) { Device.create!(name: "Test Device", location: "Test Location") }
  let!(:form) { Form.create!(name: "Test Form", button_text: "Submit") }

  def raw_request_json(overrides = {})
    {
      "slug" => "submit/260515551367356",
      "q3_whichArtist" => "Ed Sheeran",
      "q4_typeA4" => "Queen",
      "q8_score" => "100"
    }.merge(overrides).to_json
  end

  describe "POST /webhooks/trigger/:code/:device_id" do
    context "with score of 100" do
      it "creates a submission and returns 200" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id),
            params: {rawRequest: raw_request_json("q8_score" => "100")}
        }.to change(Submission, :count).by(1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "with score less than 100" do
      it "does not create a submission and returns 422" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id),
            params: {rawRequest: raw_request_json("q8_score" => "60")}
        }.not_to change(Submission, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with score of 0" do
      it "does not create a submission" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id),
            params: {rawRequest: raw_request_json("q8_score" => "0")}
        }.not_to change(Submission, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with no rawRequest param" do
      it "does not create a submission and returns 422" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id)
        }.not_to change(Submission, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with invalid JSON in rawRequest" do
      it "does not create a submission and returns 422" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id),
            params: {rawRequest: "not valid json{{{"}
        }.not_to change(Submission, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with no score field in rawRequest" do
      it "does not create a submission and returns 422" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id),
            params: {rawRequest: {"q3_whichArtist" => "Ed Sheeran"}.to_json}
        }.not_to change(Submission, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with a different question number for score" do
      it "finds the score regardless of question number" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id),
            params: {rawRequest: {"q12_score" => "100"}.to_json}
        }.to change(Submission, :count).by(1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "with multiple score fields picks the last question" do
      it "uses the highest numbered score field" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id),
            params: {rawRequest: {"q3_score" => "100", "q10_score" => "60"}.to_json}
        }.not_to change(Submission, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "passes when the highest numbered score is 100" do
        expect {
          post webhook_trigger_path(code: form.code, device_id: device.id),
            params: {rawRequest: {"q3_score" => "60", "q10_score" => "100"}.to_json}
        }.to change(Submission, :count).by(1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid form code" do
      it "returns 404" do
        post webhook_trigger_path(code: "NONEXISTENT1", device_id: device.id),
          params: {rawRequest: raw_request_json}

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with invalid device id" do
      it "returns 404" do
        post webhook_trigger_path(code: form.code, device_id: "NONEXISTENT1"),
          params: {rawRequest: raw_request_json}

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
