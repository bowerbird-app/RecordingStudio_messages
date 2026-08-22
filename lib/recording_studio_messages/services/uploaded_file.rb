# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class UploadedFile
      def initialize(file)
        @file = file
      end

      def io
        return @file[:io] if hash?

        @file.respond_to?(:tempfile) ? @file.tempfile : @file
      end

      def filename
        return @file[:filename] if hash?
        return @file.original_filename if @file.respond_to?(:original_filename)

        @file.respond_to?(:path) ? File.basename(@file.path) : "file"
      end

      def content_type
        return @file[:content_type] if hash?
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
    end
  end
end
