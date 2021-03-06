# frozen_string_literal: true

class IndexBaseFacilitiesOnLocation < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index :base_facilities, :location, using: :gist, algorithm: :concurrently
  end
end
