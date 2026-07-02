class SupportMessages < ApplicationRecord
  recording_studio_recordable label: "Support messages",
                              plural_label: "Support messages",
                              root: false,
                              allowed_parent_types: ["Workspace"]
end
