# frozen_string_literal: true

require 'common/client/base'
require 'vet360/contact_information/transaction_response'

module Vet360
  module ContactInformation
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ContactInformation::Configuration

      # GET's a Person bio from the Vet360 API
      # If a user is not found in Vet360, an empty PersonResponse with a 404 status will be returned
      # @return [Vet360::ContactInformation::PersonResponse] response wrapper around an person object
      def get_person
        with_monitoring do
          vet360_id_present!
          raw_response = perform(:get, @user.vet360_id)

          PersonResponse.from(raw_response)
        end
      rescue Common::Client::Errors::ClientError => error
        return PersonResponse.new(404, person: nil) if error.status == 404
        handle_error(error)
      rescue StandardError => e
        handle_error(e)
      end

      # POSTs a new address to the vet360 API
      # @param address [Vet360::Models::Address] the address to create
      # @return [Vet360::ContactInformation::AddressTransactionResponse] response wrapper around an transaction object
      def post_address(address)
        post_or_put_data(:post, address, 'addresses', AddressTransactionResponse)
      end

      # PUTs an updated address to the vet360 API
      # @param address [Vet360::Models::Address] the address to update
      # @return [Vet360::ContactInformation::AddressTransactionResponse] response wrapper around a transaction object
      def put_address(address)
        post_or_put_data(:put, address, 'addresses', AddressTransactionResponse)
      end

      # GET's the status of an address transaction from the Vet360 api
      # @param transaction_id [int] the transaction_id to check
      # @return [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def get_address_transaction_status(transaction_id)
        route = "#{@user.vet360_id}/addresses/status/#{transaction_id}"
        get_transaction_status(route, AddressTransactionResponse)
      end

      # POSTs a new address to the vet360 API
      # @param email [Vet360::Models::Email] the email to create
      # @return [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around an transaction object
      def post_email(email)
        post_or_put_data(:post, email, 'emails', EmailTransactionResponse)
      end

      # PUTs an updated address to the vet360 API
      # @param email [Vet360::Models::Email] the email to update
      # @return [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def put_email(email)
        post_or_put_data(:put, email, 'emails', EmailTransactionResponse)
      end

      # GET's the status of an email transaction from the Vet360 api
      # @param transaction_id [int] the transaction_id to check
      # @return [Vet360::ContactInformation::EmailTransactionResponse] response wrapper around a transaction object
      def get_email_transaction_status(transaction_id)
        route = "#{@user.vet360_id}/emails/status/#{transaction_id}"
        get_transaction_status(route, EmailTransactionResponse)
      end

      # POSTs a new telephone to the vet360 API
      # @param telephone [Vet360::Models::Telephone] the telephone to create
      # @return [Vet360::ContactInformation::TelephoneUpdateResponse] response wrapper around a transaction object
      def post_telephone(telephone)
        post_or_put_data(:post, telephone, 'telephones', TelephoneTransactionResponse)
      end

      # PUTs an updated telephone to the vet360 API
      # @param telephone [Vet360::Models::Telephone] the telephone to update
      # @return [Vet360::ContactInformation::TelephoneUpdateResponse] response wrapper around a transaction object
      def put_telephone(telephone)
        post_or_put_data(:put, telephone, 'telephones', TelephoneTransactionResponse)
      end

      # GET's the status of a telephone transaction from the Vet360 api
      # @param transaction_id [int] the transaction_id to check
      # @return [Vet360::ContactInformation::TelephoneTransactionResponse] response wrapper around a transaction object
      def get_telephone_transaction_status(transaction_id)
        route = "#{@user.vet360_id}/telephones/status/#{transaction_id}"
        get_transaction_status(route, TelephoneTransactionResponse)
      end

      # GET's the status of a person transaction from the Vet360 api. Does not validate the presence of
      # a vet360_id before making the service call, as POSTing a person initializes a vet360_id.
      #
      # @param transaction_id [String] the transaction_id to check
      # @return [Vet360::ContactInformation::PersonTransactionResponse] response wrapper around a transaction object
      #
      def get_person_transaction_status(transaction_id)
        with_monitoring do
          raw_response = perform(:get, "status/#{transaction_id}")
          Vet360::Stats.increment_transaction_results(raw_response, 'init_vet360_id')

          Vet360::ContactInformation::PersonTransactionResponse.from(raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      private

      def vet360_id_present!
        raise 'User does not have a vet360_id' if @user&.vet360_id.blank?
      end

      def post_or_put_data(method, model, path, response_class)
        with_monitoring do
          vet360_id_present!
          raw_response = perform(method, path, model.in_json)

          response_class.from(raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def get_transaction_status(path, response_class)
        with_monitoring do
          vet360_id_present!
          raw_response = perform(:get, path)
          Vet360::Stats.increment_transaction_results(raw_response)

          response_class.from(raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
