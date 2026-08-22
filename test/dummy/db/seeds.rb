# frozen_string_literal: true

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

find_or_grant = lambda do |recording, actor, role, manager|
  existing = RecordingStudioAccessible.access_recordings_for_actor(recording: recording, actor: actor)
  return existing.first if existing.present?

  if recording.parent_recording_id.blank? && RecordingStudioAccessible.access_recordings_for(recording).none?
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    raise result.error if result.failure?
    return result.value if role.to_s == "admin"
  end

  result = RecordingStudioAccessible.grant_access(
    recording: recording,
    actor: actor,
    role: role,
    manager_actor: manager
  )
  raise result.error if result.failure?

  result.value
end

tiny_png = lambda do
  ["89504E470D0A1A0A0000000D4948445200000001000000010802000000907753DE0000000C4944415408D763F8CFC00000000300017D9B4F0B0000000049454E44AE426082"].pack("H*")
end

staff = User.find_or_create_by!(email: "admin@admin.com") do |user|
  user.password = "Password"
  user.password_confirmation = "Password"
end
staff.update!(name: "Ada Staff") if staff.name != "Ada Staff"

customer = User.find_or_create_by!(email: "casey@example.com") do |user|
  user.password = "Password"
  user.password_confirmation = "Password"
end
customer.update!(name: "Casey Patron") if customer.name != "Casey Patron"

agent = Agent.find_or_create_by!(name: "Relay")

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")
mailbox = Mailbox.find_or_create_by!(name: "Site mailbox")

previous_actor = Current.actor
Current.actor = staff

begin
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)
  find_or_record_child.call(page, root_recording, folder_recording)
  mailbox_recording = find_or_record_child.call(mailbox, root_recording, root_recording)

  find_or_grant.call(root_recording, staff, :admin, staff)

  support_mount = root_recording.ensure_message_mount(DummyCatalog::SUPPORT_KEY, actor: staff)
  inbox_mount = mailbox_recording.ensure_message_mount(DummyCatalog::INBOX_KEY, actor: staff)

  support_group = RecordingStudio::Recording.find_by(
    parent_recording: support_mount,
    recordable: RecordingStudioMessages::MessageGroup.find_by(title: DummyCatalog::SUPPORT_TITLE)
  ) || RecordingStudioMessages.create_group(
    support_mount,
    title: DummyCatalog::SUPPORT_TITLE,
    actor: staff
  )

  inbox_group = RecordingStudio::Recording.find_by(
    parent_recording: inbox_mount,
    recordable: RecordingStudioMessages::MessageGroup.find_by(title: DummyCatalog::INBOX_TITLE)
  ) || RecordingStudioMessages.create_group(
    inbox_mount,
    title: DummyCatalog::INBOX_TITLE,
    actor: staff
  )

  empty_group = RecordingStudio::Recording.find_by(
    parent_recording: support_mount,
    recordable: RecordingStudioMessages::MessageGroup.find_by(title: DummyCatalog::EMPTY_TITLE)
  )
  if empty_group.blank?
    empty_group = RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioMessages::MessageGroup.new(title: DummyCatalog::EMPTY_TITLE),
      root_recording: support_mount.root_recording,
      parent_recording: support_mount,
      actor: staff
    ).recording
  end

  find_or_grant.call(support_group, staff, :admin, staff)
  find_or_grant.call(support_group, customer, :edit, staff)
  find_or_grant.call(support_group, agent, :view, staff)
  find_or_grant.call(inbox_group, customer, :admin, staff)
  find_or_grant.call(inbox_group, staff, :edit, staff)

  support_bodies = [
    [staff, "The homepage hero feels a bit loud. Can we calm it down?"],
    [customer, "Yes — I can send a quieter crop this afternoon."],
    [agent, "I queued a smaller crop of the hero still."]
  ]
  support_bodies.each do |actor, body|
    existing = RecordingStudioMessages::Message.find_by(body: body)
    next if existing.present?

    Current.actor = actor
    RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioMessages::Message.new(body: body),
      root_recording: support_group.root_recording,
      parent_recording: support_group,
      actor: actor
    )
  end

  inbox_bodies = [
    [customer, "Did the press stills land?"],
    [staff, "They are in. I attached the first frame."]
  ]
  inbox_bodies.each do |actor, body|
    existing = RecordingStudioMessages::Message.find_by(body: body)
    next if existing.present?

    Current.actor = actor
    RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioMessages::Message.new(body: body),
      root_recording: inbox_group.root_recording,
      parent_recording: inbox_group,
      actor: actor
    )
  end

  attached_message = RecordingStudio::Recording.find_by(
    recordable: RecordingStudioMessages::Message.find_by(body: "They are in. I attached the first frame.")
  )
  if attached_message && !attached_message.has_attachments?
    Current.actor = staff
    attached_message.import_attachment(
      io: StringIO.new(tiny_png.call),
      filename: "hero-still.png",
      content_type: "image/png",
      actor: staff,
      name: "Hero still"
    )
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password (Ada Staff)"
puts "Seeded: casey@example.com / Password (Casey Patron)"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Mailbox '#{mailbox.name}'"
puts "Seeded: support mount and inbox mount with conversations"
puts "Seeded: empty conversation '#{empty_group.recordable.title}'"
