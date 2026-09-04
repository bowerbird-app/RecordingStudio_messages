# frozen_string_literal: true

require "propshaft/compiler"
require "set"

# Flatpack's application stylesheet uses logical @import paths.
# Propshaft fingerprints assets but does not rewrite CSS imports by default.
class FlatpackCssImports < Propshaft::Compiler
  IMPORT_PATTERN = /@import "flat_pack\/([^"]+\.css)";/

  def compile(_asset, input)
    input.gsub(IMPORT_PATTERN) do
      imported_asset = load_path.find("flat_pack/#{Regexp.last_match(1)}")
      next Regexp.last_match(0) unless imported_asset

      %(@import url("#{url_prefix}/#{imported_asset.digested_path}");)
    end
  end

  def referenced_by(asset)
    asset.content.scan(IMPORT_PATTERN).filter_map do |(stylesheet)|
      load_path.find("flat_pack/#{stylesheet}")
    end.to_set
  end
end

Rails.application.config.assets.compilers << [ "text/css", FlatpackCssImports ]
