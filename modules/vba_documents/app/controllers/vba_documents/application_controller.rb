# frozen_string_literal: true

module VBADocuments
  class ApplicationController < ::ApplicationController
    skip_before_action :set_tags_and_extra_context
  end
end
