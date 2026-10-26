# frozen_string_literal: true

# Flatpack 0.1.315 removed Card's style: keyword. Background is the fill.
# Pinned sibling engines still pass the old style names.
module FlatpackLegacyCardStyles
  REPLACEMENTS = {
    flat: { background: :shaded, border: :none },
    elevated: { background: :default, shadow: :md },
    outlined: { background: :default, border: :strong },
    interactive: { background: :default, hover: :strong },
    list: { background: :default, hover: :subtle }
  }.freeze

  def initialize(style: nil, background: :default, shadow: nil, border: nil, hover: :none, **rest)
    if style
      replacement = REPLACEMENTS[style.to_sym]
      if replacement
        background = replacement.fetch(:background)
        shadow = replacement[:shadow] if replacement.key?(:shadow)
        border = replacement[:border] if replacement.key?(:border)
        hover = replacement[:hover] if replacement.key?(:hover)
      elsif FlatPack::Card::Background::NAMES.include?(style.to_sym)
        background = style.to_sym
      end
    end

    super(background:, shadow:, border:, hover:, **rest)
  end
end

Rails.application.config.to_prepare do
  component = FlatPack::Card::Component
  component.prepend(FlatpackLegacyCardStyles) unless component.ancestors.include?(FlatpackLegacyCardStyles)
end
