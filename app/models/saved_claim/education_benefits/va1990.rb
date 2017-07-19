# frozen_string_literal: true
class SavedClaim::EducationBenefits::VA1990 < SavedClaim::EducationBenefits
  PERSISTENT_CLASS = nil
  FORM = '22-1990'

  validates(:form_id, inclusion: %w(22-1990))
end
