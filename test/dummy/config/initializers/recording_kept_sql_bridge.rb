# frozen_string_literal: true

# API 0.23 still calls the helper Trashable 0.16 removed.
# This dummy bridge keeps those requests on RecordingStudio.kept_sql.
module RecordingKeptSqlBridge
  def recording_studio_trashable_kept_sql(table = table_name)
    RecordingStudio.kept_sql(table)
  end
end

Rails.application.config.after_initialize do
  RecordingStudio::Recording.extend(RecordingKeptSqlBridge)
end
