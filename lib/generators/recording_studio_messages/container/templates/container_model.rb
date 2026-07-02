# frozen_string_literal: true

class <%= class_name %> < ApplicationRecord
  recording_studio_recordable label: "<%= class_name.underscore.humanize %>",
                              plural_label: "<%= class_name.underscore.humanize.pluralize %>",
                              root: <%= options[:root] ? 'true' : 'false' %>,
                              allowed_parent_types: <%= options[:root] ? '[]' : options[:parent_types].inspect %>
end
