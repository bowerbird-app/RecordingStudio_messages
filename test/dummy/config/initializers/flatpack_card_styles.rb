# frozen_string_literal: true

# Flatpack 0.1.237 removed card styles :flat, :elevated, :outlined,
# :interactive, and :list. Pinned sibling engines still pass them.
# Map each one the way Flatpack's upgrade notes describe.
module FlatpackLegacyCardStyles
  REPLACEMENTS = {
    flat: { style: :shaded, border: :none },
    elevated: { style: :default, shadow: :md },
    outlined: { style: :default, border: :strong },
    interactive: { style: :default, hover: :strong },
    list: { style: :default, hover: :subtle }
  }.freeze

  def initialize(style: :default, shadow: :none, border: :default, hover: :none, **rest)
    replacement = REPLACEMENTS[style.to_sym]
    if replacement
      style = replacement.fetch(:style)
      shadow = replacement[:shadow] if replacement.key?(:shadow)
      border = replacement[:border] if replacement.key?(:border)
      hover = replacement[:hover] if replacement.key?(:hover)
    end

    super(style:, shadow:, border:, hover:, **rest)
  end
end

Rails.application.config.to_prepare do
  component = FlatPack::Card::Component
  component.prepend(FlatpackLegacyCardStyles) unless component.ancestors.include?(FlatpackLegacyCardStyles)
end
