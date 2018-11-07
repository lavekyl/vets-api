# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DependentsApplicationJob do
  describe '#perform' do
    let(:user) { create(:evss_user) }
    let!(:dependents_application) { create(:dependents_application, user: user) }

    def reload_dependents_application
      DependentsApplication.find(dependents_application.id)
    end

    context 'when there is an error' do
      it 'should set the dependents_application to failed' do
        expect_any_instance_of(EVSS::Dependents::Service).to receive(:retrieve).and_raise('foo')
        described_class.drain rescue nil
        dependents_application = reload_dependents_application
        expect(dependents_application.state).to eq('failed')
      end
    end

    it 'submits to the 686 api' do
      VCR.use_cassette(
        'evss/dependents/all',
        VCR::MATCH_EVERYTHING
      ) do
        described_class.drain

        dependents_application = reload_dependents_application
        expect(dependents_application.state).to eq('success')
        expect(dependents_application.parsed_response).to eq(
          'submit686Response' => { 'confirmationNumber' => '600142505' }
        )
      end
    end
  end
end
