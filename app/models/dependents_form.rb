# frozen_string_literal: true

class DependentsForm < Common::RedisStore
  include RedisForm

  FORM_ID = '21-686C'

  def create_submission_job
    # TODO
  end
end