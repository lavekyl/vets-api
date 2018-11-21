# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  class Configuration < Common::Client::Configuration::SOAP
    self.log_timeouts_as_warning = true
    # :nocov:
    def self.ssl_cert_path
      Settings.emis.client_cert_path
    end

    def self.ssl_key_path
      Settings.emis.client_key_path
    end
    # :nocov:

    def ssl_options
      if ssl_cert && ssl_key
        {
          client_cert: ssl_cert,
          client_key: ssl_key
        }
      end
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: ssl_options) do |conn|
        conn.use :breakers
        conn.request :soap_headers

        conn.response :soap_parser
        conn.response :betamocks if Settings.emis.mock
        conn.adapter Faraday.default_adapter
      end
    end

    def allow_missing_certs?
      true
    end
  end
end
