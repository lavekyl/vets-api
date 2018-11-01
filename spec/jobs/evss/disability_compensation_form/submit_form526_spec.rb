# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  subject { described_class }

  describe '.perform_async' do
    let(:saved_claim) { FactoryBot.create(:va526ez) }
    let(:submission) { create(:form526_submission, user_uuid: user.uuid, saved_claim_id: saved_claim.id) }
    let(:expected_claim_id) { 600130094 }

    context 'with a successfull submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          expect_any_instance_of(subject).to receive(:perform_ancillary_jobs)
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
          described_class.drain
          expect(Form526JobStatus.last.status).to eq 'success'
        end
      end

      it 'kicks off the ancillary jobs with the response claim id' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          expect_any_instance_of(subject).to receive(:perform_ancillary_jobs).with(expected_claim_id)
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
          described_class.drain
        end
      end
    end

    context 'when retrying a job' do
      it 'doesnt recreate the job status' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          expect_any_instance_of(subject).to receive(:perform_ancillary_jobs)
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)

          jid = subject.jobs.last['jid']
          values = {
            form526_submission_id: submission.id,
            job_id: jid,
            job_class: subject.class,
            status: Form526JobStatus::STATUS[:try],
            updated_at: Time.now.utc
          }
          Form526JobStatus.upsert({ job_id: jid }, values)

          described_class.drain
          expect(Form526JobStatus.last.status).to eq 'success'
          expect(Form526JobStatus.count).to eq 1
        end
      end
    end

    context 'with a submission timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'runs the retryable_error_handler and raises a EVSS::DisabilityCompensationForm::GatewayTimeout' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_retryable).once
          expect(Form526JobStatus).to receive(:upsert).twice
          expect(Rails.logger).to receive(:error).once
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::GatewayTimeout)
        end
      end
    end

    context 'with a client error' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.serviceInformation.ConfinementPastActiveDutyDate',
            'severity' => 'ERROR',
            'text' => 'The confinement start date is too far in the past'
          },
          {
            'key' => 'form526.serviceInformation.ConfinementWithInServicePeriod',
            'severity' => 'ERROR',
            'text' => 'Your period of confinement must be within a single period of service'
          },
          {
            'key' => 'form526.veteran.homelessness.pointOfContact.pointOfContactName.Pattern',
            'severity' => 'ERROR',
            'text' => 'must match "([a-zA-Z0-9-/]+( ?))*$"'
          }
        ]
      end

      it 'sets the job_status to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_400') do
          expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with a server error' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.submit.establishClaim.serviceError',
            'text' => 'form526.submit.establishClaim.serviceError',
            'severity' => 'FATAL'
          }
        ]
      end

      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_err_msg') do
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with a max ep code server error' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.submit.save.draftForm.MaxEPCode',
            'severity' => 'FATAL',
            'text' => 'This claim could not be established. ' \
'The Maximum number of EP codes have been reached for this benefit type claim code'
          }
        ]
      end

      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_max_ep_code') do
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with a pif in use server error' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.submit.save.draftForm.MaxEPCode',
            'severity' => 'FATAL',
            'text' => 'Claim could not be established. ' \
'Contact the BDN team and have them run the WIPP process to delete Cancelled/Cleared PIFs'
          }
        ]
      end

      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_pif_in_use') do
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with an error that is not mapped' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.submit.save.draftForm.UnmappedError',
            'severity' => 'FATAL',
            'text' => 'This is an unmapped error message'
          }
        ]
      end

      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_unmapped') do
          subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
          described_class.drain
          expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
        end
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'sets the transaction to "non_retryable_error"' do
        subject.perform_async(user.uuid, auth_headers, saved_claim.id, submission.id)
        described_class.drain
        expect(Form526JobStatus.last.status).to eq Form526JobStatus::STATUS[:non_retryable_error]
      end
    end
  end

  describe '#workflow_complete_handler' do
    let(:saved_claim) { instance_double('SavedClaim::DisabilityCompensation') }
    let(:submission) { create(:disability_compensation_submission) }

    before do
      allow_any_instance_of(subject).to receive(:saved_claim).and_return(saved_claim)
      allow(saved_claim).to receive(:submission).and_return(submission)
    end

    it 'sets the submission.complete to true' do
      expect(submission.complete).to be_falsey
      subject.new.workflow_complete_handler(nil, 'saved_claim_id' => 123)
      expect(submission.complete).to be_truthy
    end
  end
end
