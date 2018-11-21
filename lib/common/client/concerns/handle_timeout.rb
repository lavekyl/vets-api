# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module HandleTimeout
        include SentryLogging

        def handle_timeout(error)
          StatsD.increment(@timeout_key) if @timeout_key
          @extra_context ||= {}
          @error_tags_context ||= {}
          log_exception_to_sentry(error, extra_context: @extra_context, tags_context: @error_tags_context, level: :warn)
          raise Common::Exceptions::SentryIgnoredGatewayTimeout
        end
      end
    end
  end
end
