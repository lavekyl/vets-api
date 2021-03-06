# frozen_string_literal: true

class BackendStatusSerializer < ActiveModel::Serializer
  attribute :name
  attribute :is_available
  attribute :uptime_remaining

  def id
    nil
  end
end
