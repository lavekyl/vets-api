# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability compensation form', type: :request do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user) }
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}", 'CONTENT_TYPE' => 'application/json' } }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'Get /v0/disability_compensation_form/rated_disabilities' do
    context 'with a valid 200 evss response' do
      it 'should match the rated disabilities schema' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('rated_disabilities')
        end
      end
    end

    context 'with a 500 response' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_500') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 403 unauthorized response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_403') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a generic 400 response' do
      it 'should return a bad request response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_400') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 401 response' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_401') do
          get '/v0/disability_compensation_form/submit', nil, auth_header
          expect(response).to have_http_status(:not_found)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end

  describe 'Post /v0/disability_compensation_form/suggested_conditions/:name_part' do
    before(:each) do
      create(:disability_contention_arrhythmia)
      create(:disability_contention_arteriosclerosis)
      create(:disability_contention_arthritis)
    end

    let(:conditions) { JSON.parse(response.body)['data'] }

    it 'returns matching conditions', :aggregate_failures do
      get '/v0/disability_compensation_form/suggested_conditions?name_part=art', nil, auth_header
      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('suggested_conditions')
      expect(conditions.count).to eq 3
    end

    it 'returns an empty array when no conditions match', :aggregate_failures do
      get '/v0/disability_compensation_form/suggested_conditions?name_part=xyz', nil, auth_header
      expect(response).to have_http_status(:ok)
      expect(conditions.count).to eq 0
    end

    it 'returns a 500 when name_part is missing' do
      get '/v0/disability_compensation_form/suggested_conditions', nil, auth_header
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'Post /v0/disability_compensation_form/submit' do
    before(:each) do
      VCR.insert_cassette('emis/get_military_service_episodes/valid')
      VCR.insert_cassette('evss/ppiu/payment_information')
      VCR.insert_cassette('evss/intent_to_file/active_compensation')
    end

    after(:each) do
      VCR.eject_cassette('emis/get_military_service_episodes/valid')
      VCR.eject_cassette('evss/ppiu/payment_information')
      VCR.eject_cassette('evss/intent_to_file/active_compensation')
    end

    context 'with a valid 200 evss response' do
      let(:jid) { "JID-#{SecureRandom.base64}" }

      before(:each) do
        allow(EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly).to receive(:perform_async).and_return(jid)
        allow(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim).to receive(:perform_async).and_return(jid)
      end

      before do
        create(:in_progress_form, form_id: VA526ez::FORM_ID, user_uuid: user.uuid)
      end

      context 'with an `increase only` claim' do
        let(:valid_increase_form) { File.read 'spec/support/disability_compensation_form/front_end_submission.json' }

        it 'should match the submit_disability_form schema' do
          VCR.use_cassette('evss/disability_compensation_form/submit_form') do
            post '/v0/disability_compensation_form/submit', valid_increase_form, auth_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('submit_disability_form')
          end
        end

        it 'should start the submit job' do
          VCR.use_cassette('evss/disability_compensation_form/submit_form') do
            expect(EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly).to receive(:perform_async).once
            post '/v0/disability_compensation_form/submit', valid_increase_form, auth_header
          end
        end
      end

      context 'with an `all claims` claim' do
        let(:all_claims_form) { File.read 'spec/support/disability_compensation_form/all_claims_fe_submission.json' }

        it 'should match the rated disabilites schema' do
          VCR.use_cassette('evss/disability_compensation_form/submit_form') do
            post '/v0/disability_compensation_form/submit_all_claim', all_claims_form, auth_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('submit_disability_form')
          end
        end

        it 'should start the submit job' do
          VCR.use_cassette('evss/disability_compensation_form/submit_form') do
            expect(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim).to receive(:perform_async).once
            post '/v0/disability_compensation_form/submit_all_claim', all_claims_form, auth_header
          end
        end
      end
    end

    context 'with invalid json body' do
      it 'should return a 500' do
        post '/v0/disability_compensation_form/submit', { 'form526' => nil }.to_json, auth_header
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'Get /v0/disability_compensation_form/submission_status' do
    context 'with a success status' do
      let(:submission) { create(:form526_submission, submitted_claim_id: 61_234_567) }
      let(:job_status) { create(:form526_job_status, form526_submission_id: submission.id) }

      it 'should return the job status and response', :aggregate_failures do
        get "/v0/disability_compensation_form/submission_status/#{job_status.job_id}", nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_deep_attributes(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => 61_234_567,
              'job_id' => job_status.job_id,
              'status' => 'success'
            }
          }
        )
      end
    end

    context 'with a retryable_error status' do
      let(:submission) { create(:form526_submission) }
      let(:job_status) { create(:form526_job_status, :retryable_error, form526_submission_id: submission.id) }

      it 'should return the job status and response', :aggregate_failures do
        get "/v0/disability_compensation_form/submission_status/#{job_status.job_id}", nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_deep_attributes(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => nil,
              'job_id' => job_status.job_id,
              'status' => 'retryable_error'
            }
          }
        )
      end
    end

    context 'with a non_retryable_error status' do
      let(:submission) { create(:form526_submission) }
      let(:job_status) { create(:form526_job_status, :non_retryable_error, form526_submission_id: submission.id) }

      it 'should return the job status and response', :aggregate_failures do
        get "/v0/disability_compensation_form/submission_status/#{job_status.job_id}", nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_deep_attributes(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => nil,
              'job_id' => job_status.job_id,
              'status' => 'non_retryable_error'
            }
          }
        )
      end
    end

    context 'when no record is found' do
      it 'should return the async submit transaction status and response', :aggregate_failures do
        get '/v0/disability_compensation_form/submission_status/123', nil, auth_header
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
