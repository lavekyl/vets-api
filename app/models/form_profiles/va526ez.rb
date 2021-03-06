# frozen_string_literal: true

module VA526ez
  FORM_ID = '21-526EZ'

  class FormSpecialIssue
    include Virtus.model

    attribute :code, String
    attribute :name, String
  end

  class FormRatedDisability
    include Virtus.model

    attribute :name, String
    attribute :rated_disability_id, String
    attribute :rating_decision_id, String
    attribute :diagnostic_code, Integer
    attribute :decision_code, String
    attribute :decision_text, String
    attribute :rating_percentage, Integer
  end

  class FormRatedDisabilities
    include Virtus.model

    attribute :rated_disabilities, Array[FormRatedDisability]
  end

  class FormPaymentAccountInformation
    include Virtus.model

    attribute :account_type, String
    attribute :account_number, String
    attribute :routing_number, String
    attribute :bank_name, String
  end

  class FormAddress
    include Virtus.model

    attribute :country
    attribute :city
    attribute :state
    attribute :zip_code
    attribute :address_line_1
    attribute :address_line_2
    attribute :address_line_3
  end

  class FormContactInformation
    include Virtus.model

    attribute :mailing_address, FormAddress
    attribute :primary_phone, String
    attribute :email_address, String
  end

  class FormVeteranContactInformation
    include Virtus.model

    attribute :veteran, FormContactInformation
  end
end

class FormProfiles::VA526ez < FormProfile
  attribute :rated_disabilities_information, VA526ez::FormRatedDisabilities
  attribute :veteran_contact_information, VA526ez::FormContactInformation
  attribute :payment_information, VA526ez::FormPaymentAccountInformation

  def prefill(user)
    @rated_disabilities_information = initialize_rated_disabilities_information(user)
    @veteran_contact_information = initialize_veteran_contact_information(user)
    @payment_information = initialize_payment_information(user)
    super(user)
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  private

  def initialize_veteran_contact_information(user)
    return {} unless user.authorize :evss, :access?

    pciu_email = extract_pciu_data(user, :pciu_email)
    pciu_primary_phone = extract_pciu_data(user, :pciu_primary_phone)

    contact_info = VA526ez::FormContactInformation.new(
      mailing_address: get_common_address(user),
      email_address: pciu_email,
      primary_phone: get_us_phone(pciu_primary_phone)
    )

    VA526ez::FormVeteranContactInformation.new(
      veteran: contact_info
    )
  end

  def initialize_rated_disabilities_information(user)
    return {} unless user.authorize :evss, :access?
    service = EVSS::DisabilityCompensationForm::Service.new(
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    )
    response = service.get_rated_disabilities

    # Remap response object to schema fields
    VA526ez::FormRatedDisabilities.new(
      rated_disabilities: response.rated_disabilities
    )
  end

  # Convert PCIU address to a Common address type
  def get_common_address(user)
    service = EVSS::PCIUAddress::Service.new(user)
    response = service.get_address
    case response.address
    when EVSS::PCIUAddress::DomesticAddress
      prefill_domestic_address(response.address)
    when EVSS::PCIUAddress::InternationalAddress
      prefill_international_address(response.address)
    when EVSS::PCIUAddress::MilitaryAddress
      prefill_military_address(response.address)
    else
      {}
    end
  rescue StandardError
    {}
  end

  def prefill_domestic_address(address)
    {
      country: address&.country_name,
      city: address&.city,
      state: address&.state_code,
      zip_code: address&.zip_code,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end

  def prefill_international_address(address)
    {
      country: address&.country_name,
      city: address&.city,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end

  def prefill_military_address(address)
    {
      country: 'USA',
      city: address&.military_post_office_type_code,
      state: address&.military_state_code,
      zip_code: address&.zip_code,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end

  def initialize_payment_information(user)
    return {} unless user.authorize :evss, :access?

    service = EVSS::PPIU::Service.new(user)
    response = service.get_payment_information
    raw_account = response.responses.first&.payment_account

    if raw_account
      VA526ez::FormPaymentAccountInformation.new(
        account_type: raw_account&.account_type&.capitalize,
        account_number: mask(raw_account&.account_number),
        routing_number: mask(raw_account&.financial_institution_routing_number),
        bank_name: raw_account&.financial_institution_name
      )
    else
      {}
    end
  rescue StandardError => e
    Rails.logger.error "Failed to retrieve PPIU data: #{e.message}"
    {}
  end

  def mask(number)
    number.gsub(/.(?=.{4})/, '*')
  end
end
