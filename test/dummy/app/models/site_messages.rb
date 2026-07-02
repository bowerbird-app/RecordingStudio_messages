class SiteMessages < ApplicationRecord
  recording_studio_recordable label: "Site messages",
                              plural_label: "Site messages",
                              root: true,
                              allowed_parent_types: []
end
