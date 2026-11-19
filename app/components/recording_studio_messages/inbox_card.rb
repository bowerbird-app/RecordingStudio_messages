# frozen_string_literal: true

module RecordingStudioMessages
  class InboxCard < ViewComponent::Base
    extend InboxCardRegistration

    WIDGET_ID = :messages_inbox

    def initialize(actor: nil, title: nil, mine: false, mount: nil,
                   limit: Services::InboxCard::PREVIEW_LIMIT, preparation: nil, **_dashboard)
      @source = card_source(preparation, actor:, title:, mine:, mount:, limit:)
      super()
    end

    def render?
      @source&.visible? == true
    end

    def call
      render(FlatPack::Card::Component.new(padding: :sm, class: "min-w-0 h-full", data: card_data)) do |card|
        card.header(padding: :sm) do
          render(FlatPack::Cluster::Component.new(align: :center, justify: :between, gap: :sm)) do
            safe_join([heading, unread_badge].compact)
          end
        end
        card.body(padding: :none) { conversation_list }
        card.footer(padding: :sm) { open_inbox }
      end
    end

    private

    def card_source(preparation, actor:, title:, mine:, mount:, limit:)
      return preparation.data if preparation

      Services::InboxCard.build(actor:, title:, mine:, mount:, limit:)
    end

    def card_data
      { inbox_card: @source.mine? ? "mine" : "mount" }
    end

    def heading
      render(FlatPack::Heading::Component.new(text: @source.title, level: 2, size: :sm))
    end

    def unread_badge
      return unless @source.unread_count.positive?

      render(
        FlatPack::Badge::Component.new(
          text: @source.unread_count.to_s,
          style: :primary,
          size: :sm,
          aria: { label: Copy.t("inbox_card.unread", count: @source.unread_count) }
        )
      )
    end

    def conversation_list
      rows = helpers.messages_inbox_rows(@source.groups, inbox: @source.row_inbox, actor: @source.actor)
      render(FlatPack::List::Component.new(spacing: :dense)) do
        safe_join(rows.map { |row| inbox_row(row) })
      end
    end

    def inbox_row(row)
      render(FlatPack::Chat::InboxRow::Component.new(**row.except(:title_frame_id)))
    end

    def open_inbox
      render(
        FlatPack::Button::Component.new(
          text: Copy.t("inbox_card.see_all"),
          href: inbox_href,
          style: :ghost,
          size: :sm
        )
      )
    end

    def inbox_href
      routes = helpers.recording_studio_messages
      return routes.my_messages_path if @source.mine?

      routes.message_groups_path(mount_id: @source.mount.id)
    end
  end
end
