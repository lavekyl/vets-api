# frozen_string_literal: true

require 'upsert/active_record_upsert'

class DisabilityCompensationJobStatus < ActiveRecord::Base
  belongs_to :disability_compensation_submission

  alias_attribute :submission, :disability_compensation_submission
end
