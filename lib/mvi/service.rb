# frozen_string_literal: true

require 'common/client/base'
require 'mvi/configuration'
require 'mvi/responses/find_profile_response'
require 'common/client/concerns/monitoring'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'
require 'mvi/errors/errors'
require 'sentry_logging'

module MVI
  # Wrapper for the MVI (Master Veteran Index) Service. vets.gov has access
  # to three MVI endpoints:
  # * PRPA_IN201301UV02 (TODO(AJD): Add Person)
  # * PRPA_IN201302UV02 (TODO(AJD): Update Person)
  # * PRPA_IN201305UV02 (aliased as .find_profile)
  class Service < Common::Client::Base
    include Common::Client::Monitoring

    # The MVI Service SOAP operations vets.gov has access to
    unless const_defined?(:OPERATIONS)
      OPERATIONS = {
        add_person: 'PRPA_IN201301UV02',
        update_person: 'PRPA_IN201302UV02',
        find_profile: 'PRPA_IN201305UV02'
      }.freeze
    end

    # @return [MVI::Configuration] the configuration for this service
    configuration MVI::Configuration

    STATSD_KEY_PREFIX = 'api.mvi' unless const_defined?(:STATSD_KEY_PREFIX)

    # Given a user queries MVI and returns their VA profile.
    #
    # @param user [User] the user to query MVI for
    # @return [MVI::Responses::FindProfileResponse] the parsed response from MVI.
    # rubocop:disable Metrics/MethodLength
    def find_profile(user)
      with_monitoring do
        Rails.logger.measure_info('Performed MVI Query', payload: logging_context(user)) do
          raw_response = perform(:post, '', create_profile_message(user), soapaction: OPERATIONS[:find_profile])
          MVI::Responses::FindProfileResponse.with_parsed_response(raw_response)
        end
      end
    rescue Breakers::OutageException => e
      Raven.extra_context(breakers_error_message: e.message)
      log_console_and_sentry('MVI find_profile connection failed.', :error)
      MVI::Responses::FindProfileResponse.with_server_error
    rescue Faraday::ConnectionFailed => e
      log_console_and_sentry("MVI find_profile connection failed: #{e.message}", :error)
      MVI::Responses::FindProfileResponse.with_server_error
    rescue Common::Client::Errors::ClientError, Common::Exceptions::GatewayTimeout => e
      log_console_and_sentry("MVI find_profile error: #{e.message}", :error)
      MVI::Responses::FindProfileResponse.with_server_error
    rescue MVI::Errors::Base => e
      mvi_error_handler(user, e)
      if e.is_a?(MVI::Errors::RecordNotFound)
        MVI::Responses::FindProfileResponse.with_not_found
      else
        MVI::Responses::FindProfileResponse.with_server_error
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    def mvi_error_handler(user, e)
      case e
      when MVI::Errors::DuplicateRecords
        log_console_and_sentry('MVI Duplicate Record', :warn)
      when MVI::Errors::RecordNotFound
        log_console_and_sentry('MVI Record Not Found')
      when MVI::Errors::InvalidRequestError
        # NOTE: ICN based lookups do not return RecordNotFound. They return InvalidRequestError
        if user.mhv_icn.present?
          log_console_and_sentry('MVI Invalid Request (Possible RecordNotFound)', :error)
        else
          log_console_and_sentry('MVI Invalid Request', :error)
        end
      when MVI::Errors::FailedRequestError
        log_console_and_sentry('MVI Failed Request', :error)
      end
    end

    def log_console_and_sentry(message, sentry_classification = nil)
      Rails.logger.info(message)
      log_message_to_sentry(message, sentry_classification) if sentry_classification.present?
    end

    def logging_context(user)
      {
        uuid: user.uuid,
        authn_context: user.authn_context
      }
    end

    def create_profile_message(user)
      return message_icn(user) if user.mhv_icn.present? # from SAML::UserAttributes::MHV::BasicLOA3User
      return message_edipi(user) if user.dslogon_edipi.present? && Settings.mvi.edipi_search
      raise Common::Exceptions::ValidationErrors, user unless user.valid?(:loa3_user)
      message_user_attributes(user)
    end

    def message_icn(user)
      MVI::Messages::FindProfileMessageIcn.new(user.mhv_icn).to_xml
    end

    def message_edipi(user)
      MVI::Messages::FindProfileMessageEdipi.new(user.dslogon_edipi).to_xml
    end

    def message_user_attributes(user)
      given_names = [user.first_name]
      given_names.push user.middle_name unless user.middle_name.nil?
      MVI::Messages::FindProfileMessage.new(
        given_names,
        user.last_name,
        user.birth_date,
        user.ssn,
        user.gender
      ).to_xml
    end
  end
end
