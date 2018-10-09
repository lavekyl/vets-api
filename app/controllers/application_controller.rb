# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'aes_256_cbc_encryptor'

class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ActionController::Cookies
  include SentryLogging
  include Pundit

  SKIP_SENTRY_EXCEPTION_TYPES = [
    Common::Exceptions::Unauthorized,
    Common::Exceptions::RoutingError,
    Common::Exceptions::Forbidden,
    Breakers::OutageException,
    Common::Exceptions::SentryIgnoredGatewayTimeout
  ].freeze

  before_action :authenticate
  before_action :determine_session_for_non_authed_resource # See method description before skipping
  before_action :extend_session! # See method description before skipping (there should be no reason)
  before_action :set_app_info_headers
  before_action :set_tags_and_extra_context
  skip_before_action :authenticate, only: %i[cors_preflight routing_error]

  def tag_rainbows
    Sentry::TagRainbows.tag
  end

  def cors_preflight
    head(:ok)
  end

  def clear_saved_form(form_id)
    InProgressForm.form_for_user(form_id, @current_user)&.destroy if @current_user
  end

  def routing_error
    raise Common::Exceptions::RoutingError, params[:path]
  end

  # I'm commenting this out for now, we can put it back in if we encounter it
  # def action_missing(m, *_args)
  #   Rails.logger.error(m)
  #   raise Common::Exceptions::RoutingError
  # end

  private

  attr_reader :current_user, :session

  def skip_sentry_exception_types
    SKIP_SENTRY_EXCEPTION_TYPES
  end

  # rubocop:disable Metrics/BlockLength
  rescue_from 'Exception' do |exception|
    # report the original 'cause' of the exception when present
    if skip_sentry_exception_types.include?(exception.class)
      Rails.logger.error "#{exception.message}."
      Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
    else
      extra = exception.respond_to?(:errors) ? { errors: exception.errors.map(&:to_hash) } : {}
      if exception.is_a?(Common::Exceptions::BackendServiceException)
        # Add additional user specific context to the logs
        if current_user.present?
          extra[:icn] = current_user.icn
          extra[:mhv_correlation_id] = current_user.mhv_correlation_id
        end
        # Warn about VA900 needing to be added to exception.en.yml
        if exception.generic_error?
          log_message_to_sentry(exception.va900_warning, :warn, i18n_exception_hint: exception.va900_hint)
        end
      end
      log_exception_to_sentry(exception, extra)
    end

    va_exception =
      case exception
      when Pundit::NotAuthorizedError
        Common::Exceptions::Forbidden.new(detail: 'User does not have access to the requested resource')
      when ActionController::ParameterMissing
        Common::Exceptions::ParameterMissing.new(exception.param)
      when ActionController::UnknownFormat
        Common::Exceptions::UnknownFormat.new
      when Common::Exceptions::BaseError
        exception
      when Breakers::OutageException
        Common::Exceptions::ServiceOutage.new(exception.outage)
      when Common::Client::Errors::ClientError
        # SSLError, ConnectionFailed, SerializationError, etc
        Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
      else
        Common::Exceptions::InternalServerError.new(exception)
      end

    headers['WWW-Authenticate'] = 'Token realm="Application"' if va_exception.is_a?(Common::Exceptions::Unauthorized)
    render json: { errors: va_exception.errors }, status: va_exception.status_code
  end
  # rubocop:enable Metrics/BlockLength

  def set_tags_and_extra_context
    Thread.current['request_id'] = request.uuid
    Raven.extra_context(request_uuid: request.uuid)
    Raven.user_context(user_context) if @current_user
    Raven.tags_context(tags_context)
  end

  def user_context
    {
      uuid: @current_user&.uuid,
      authn_context: @current_user&.authn_context,
      loa: @current_user&.loa,
      mhv_icn: @current_user&.mhv_icn
    }
  end

  def tags_context
    {
      controller_name: controller_name,
      sign_in_method: @current_user.present? ? @current_user.authn_context || 'idme' : 'not-signed-in'
    }
  end

  def set_app_info_headers
    headers['X-GitHub-Repository'] = 'https://github.com/department-of-veterans-affairs/vets-api'
    headers['X-Git-SHA'] = AppInfo::GIT_REVISION
  end

  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    cookie_token_authentication || header_token_authentication
  end

  def render_unauthorized
    raise Common::Exceptions::Unauthorized
  end

  def cookie_token_authentication
    return unless Settings.sso.cookie_enabled
    @session = Session.find(cookie_object['vagovToken'])
    return false if @session.nil?
    @current_user = User.find(@session.uuid)
    return true if @current_user.present?
  end

  def header_token_authentication
    authenticate_with_http_token do |token, _options|
      @session = Session.find(token)
      return false if @session.nil?
      @current_user = User.find(@session.uuid)
      return true if @current_user.present?
    end
  end

  # If cookies are enabled, we can extend sessions and log better errors by knowing the current_user
  # even if the resource does not pass or require authentication headers.
  def determine_session_for_non_authed_resource
    return unless Settings.sso.cookie_enabled
    @session ||= Session.find(cookie_object['vagovToken'])
    @current_user ||= User.find(@session.uuid)
  end

  # As long as a current_user and session are known, we should extend their session.
  # If cookies are disabled, the only way we can know the session is via authentication headers
  # These headers are never provided by FE for resources that do not require it.
  def extend_session!
    return if session.blank? || current_user.blank?
    session.expire(Session.redis_namespace_ttl)
    current_user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    current_user&.expire(User.redis_namespace_ttl)
    set_sso_cookie!
  end

  # https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/SSO/CookieSpecs-20180906.docx
  def set_sso_cookie!
    return unless Settings.sso.cookie_enabled
    encryptor = SSOEncryptor
    contents = ActiveSupport::JSON.encode(@session.cookie_data)
    encrypted_value = encryptor.encrypt(contents)
    cookies[Settings.sso.cookie_name] = {
      value: encrypted_value,
      expires: @session.ttl_in_time,
      secure: true,
      httponly: true,
      domain: cookie_domain
    }
  end

  def destroy_sso_cookie!
    cookies.delete(Settings.sso.cookie_name, domain: cookie_domain)
  end

  def saml_settings(options = {})
    SAML::SettingsService.saml_settings(options)
  end

  def pagination_params
    {
      page: params[:page],
      per_page: params[:per_page]
    }
  end

  def render_job_id(jid)
    render json: { job_id: jid }, status: 202
  end

  def cookie_object
    return @cookie_object unless @cookie_object.nil?
    return {} if cookies[Settings.sso.cookie_name].blank?
    encryptor = SSOEncryptor
    decrypted_value = encryptor.decrypt(cookies[Settings.sso.cookie_name])
    cookie_object = JSON.parse(decrypted_value)
    @cookie_object = cookie_object
  end

  def cookie_domain
    '.va.gov'
  end
end
