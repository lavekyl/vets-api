# frozen_string_literal: true

require 'attr_encrypted'

class Form526OptIn < ActiveRecord::Base
  attr_encrypted(:email, key: Settings.db_encryption_key)

  validates(:email, :user_uuid, presence: true)
end
