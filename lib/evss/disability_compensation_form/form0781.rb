# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Form0781
      def initialize(user, form_content)
        @user = user
        @phone_email = form_content.dig('form526', 'phoneAndEmail')
        @final_output = form_content.dig('form526', 'form0781')
      end

      def translate
        return nil unless @final_output
        @final_output['vaFileNumber'] = @user.ssn
        @final_output['veteranSocialSecurityNumber'] = @user.ssn
        @final_output['veteranFullName'] = full_name
        @final_output['veteranDateOfBirth'] = @user.birth_date
        @final_output['email'] = @phone_email['emailAddress']
        @final_output['veteranPhone'] = @phone_email['primaryPhone']
        @final_output['veteranSecondaryPhone'] = '' # No secondary phone available in 526 PreFill
        @final_output['veteranServiceNumber'] = '' # No veteran service number available in 526 PreFill
        @final_output
      end

      private

      def full_name
        {
          'first' => @user.first_name,
          'middle' => @user.middle_name,
          'last' => @user.last_name
        }
      end
    end
  end
end
