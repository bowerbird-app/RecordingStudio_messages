import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["references"]

  connect() {
    this.onInsert = this.onInsert.bind(this)
    window.addEventListener("messages:composer-insert", this.onInsert)
  }

  disconnect() {
    window.removeEventListener("messages:composer-insert", this.onInsert)
  }

  onInsert(event) {
    const detail = event.detail || {}
    if (detail.text) this.appendText(detail.text)
    if (detail.reference) this.addReference(detail.reference)
  }

  appendText(text) {
    const field = this.bodyField()
    if (!field) return

    const chunk = text.toString()
    field.value = field.value ? `${field.value.replace(/\s+$/, "")}\n\n${chunk}` : chunk
    field.dispatchEvent(new Event("input", { bubbles: true }))
  }

  addReference(reference) {
    if (!this.hasReferencesTarget) return
    if (!reference.recording_id) return
    if (this.existingIds().includes(String(reference.recording_id))) return

    const index = this.referencesTarget.children.length
    this.referencesTarget.append(this.hiddenInput(index, "recording_id", reference.recording_id))
    if (reference.title) this.referencesTarget.append(this.hiddenInput(index, "title", reference.title))
    if (reference.url) this.referencesTarget.append(this.hiddenInput(index, "url", reference.url))
  }

  existingIds() {
    return Array.from(
      this.referencesTarget.querySelectorAll('input[name*="[recording_id]"]')
    ).map((input) => input.value)
  }

  hiddenInput(index, field, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = `message[references][${index}][${field}]`
    input.value = value
    return input
  }

  bodyField() {
    return this.element.querySelector('textarea[name="message[body]"]')
  }
}
