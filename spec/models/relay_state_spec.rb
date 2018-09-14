# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RelayState, type: :model do
  let(:relay_url) { Settings.saml.relays.vagov }
  let(:invalid_relay_url) { 'https://fake-attacker-site.com' }
  let(:logout_relay_url) { Settings.saml.logout_relays.vagov }
  let(:invalid_logout_relay_url) { 'https://fake-attacker-logout.com' }
  let(:relay_enum) { Settings.saml.relays.keys.second.to_s }
  let(:invalid_relay_enum) { 'foo' }

  describe '.login_relay' do
    context 'with a valid RelayState & success_relay' do
      subject { described_class.new(relay_enum: relay_enum, url: relay_url) }

      it 'is valid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns RelayState' do
        expect(subject.login_url).to eq(relay_url)
      end
      it '#logout_url returns nil' do
        expect(subject.logout_url).to eq(nil)
      end
    end

    context 'when no params are provided' do
      subject { described_class.new(relay_enum: nil, url: nil) }

      it 'is invalid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns default' do
        expect(subject.login_url).to eq(Settings.saml.relays.vetsgov)
      end
      it '#logout_url returns default' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays.vetsgov)
      end
    end

    context 'with an valid enum and invalid RelayState' do
      subject { described_class.new(relay_enum: relay_enum, url: invalid_relay_url) }

      it 'is invalid' do
        expect(subject.valid?).to be_falsey
      end
      it '#login_url returns default' do
        expect(subject.login_url).to eq(Settings.saml.relays.vetsgov)
      end
      it '#logout_url returns default' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays.vetsgov)
      end
      it 'logs a error to sentry' do
        expect_any_instance_of(described_class).to receive(:log_message_to_sentry).once
          .with(
            'Invalid SAML RelayState!',
            :error,
            url_whitelist: described_class::ALL_RELAY_URLS, enum_whitelist: described_class::RELAY_KEYS
          )
        subject.dup
      end
    end

    context 'with a valid RelayState and an ivalid success_relay' do
      subject { described_class.new(relay_enum: invalid_relay_enum, url: relay_url) }

      it 'is invalid' do
        expect(subject.valid?).to be_falsey
      end
      it '#login_url returns default' do
        expect(subject.login_url).to eq(Settings.saml.relays.vetsgov)
      end
      it '#logout_url returns default' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays.vetsgov)
      end
      it 'logs a error to sentry' do
        expect_any_instance_of(described_class).to receive(:log_message_to_sentry).once
          .with(
            'Invalid SAML RelayState!',
            :error,
            url_whitelist: described_class::ALL_RELAY_URLS, enum_whitelist: described_class::RELAY_KEYS
          )
        subject.dup
      end
    end

    context 'with a valid login RelayState and nil success_relay' do
      subject { described_class.new(url: relay_url) }

      it 'is valid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns RelayState' do
        expect(subject.login_url).to eq(relay_url)
      end
      it '#logout_url returns nil' do
        expect(subject.logout_url).to eq(nil)
      end
    end

    context 'with a valid logout RelayState and nil success_relay' do
      subject { described_class.new(url: logout_relay_url) }

      it 'is valid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns nil' do
        expect(subject.login_url).to eq(nil)
      end
      it '#logout_url returns RelayState' do
        expect(subject.logout_url).to eq(logout_relay_url)
      end
    end

    context 'with a valid success_relay only' do
      subject { described_class.new(relay_enum: relay_enum) }
      it 'is valid' do
        expect(subject.valid?).to be_truthy
      end
      it '#login_url returns the enum-appropriate login url' do
        expect(subject.login_url).to eq(Settings.saml.relays[relay_enum])
      end
      it '#logout_url returns the enum-appropriate logout url' do
        expect(subject.logout_url).to eq(Settings.saml.logout_relays[relay_enum])
      end
    end
  end
end
