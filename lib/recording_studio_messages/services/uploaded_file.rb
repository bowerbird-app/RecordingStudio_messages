# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class UploadedFile
      def initialize(file)
        @file = file
      end

      def io
        return @file[:io] if hash?
        return opened_blob if blob?
        return @file.tempfile if @file.respond_to?(:tempfile)

        @file
      end

      def filename
        return @file[:filename] if hash?
        return @file.filename.to_s if blob?
        return @file.original_filename if @file.respond_to?(:original_filename)

        @file.respond_to?(:path) ? File.basename(@file.path) : "file"
      end

      def content_type
        return @file[:content_type] if hash?
        return blob_content_type if blob?
        return @file.content_type if @file.respond_to?(:content_type)

        "application/octet-stream"
      end

      def name
        return @file[:name] if hash?

        File.basename(filename, File.extname(filename))
      end

      private

      def hash?
        @file.is_a?(Hash)
      end

      def blob?
        defined?(ActiveStorage::Blob) && @file.is_a?(ActiveStorage::Blob)
      end

      def opened_blob
        return @opened_blob if defined?(@opened_blob)

        @opened_blob = StringIO.new(@file.download)
      end

      def blob_content_type
        @file.content_type.presence || "application/octet-stream"
      end
    end
  end
end
