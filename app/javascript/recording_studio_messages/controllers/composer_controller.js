import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["references", "chipTemplate"]

  connect() {
    this.onInsert = this.onInsert.bind(this)
    this.onChipRemoved = this.onChipRemoved.bind(this)
    window.addEventListener("messages:composer-insert", this.onInsert)
    this.element.addEventListener("chip:removed", this.onChipRemoved)
  }

  disconnect() {
    window.removeEventListener("messages:composer-insert", this.onInsert)
    this.element.removeEventListener("chip:removed", this.onChipRemoved)
  }

  onInsert(event) {
    const detail = event.detail || {}
    if (detail.reference) {
      this.addReference(detail.reference)
    } else if (detail.text) {
      this.appendText(detail.text)
    }
    this.closeOpenActionModal()
  }

  closeOpenActionModal() {
    document.querySelectorAll("[id^='messages-composer-action-']").forEach((modal) => {
      if (!modal.matches("[data-controller~='flat-pack--modal']")) return
      if (modal.classList.contains("hidden")) return

      modal.querySelector("[data-action='flat-pack--modal#close']")?.click()
    })
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

    const index = `${Date.now()}${this.referencesTarget.children.length}`
    const wrap = document.createElement("div")
    wrap.dataset.pendingReference = "true"
    wrap.className = "inline-flex"
    wrap.append(this.hiddenInput(index, "recording_id", reference.recording_id))
    if (reference.title) wrap.append(this.hiddenInput(index, "title", reference.title))
    if (reference.url) wrap.append(this.hiddenInput(index, "url", reference.url))
    wrap.append(this.chipFor(reference.title))
    this.referencesTarget.append(wrap)
  }

  chipFor(title) {
    if (!this.hasChipTemplateTarget) return document.createTextNode(title || "")

    const html = this.chipTemplateTarget.innerHTML.replaceAll("__TITLE__", title || "")
    const wrap = document.createElement("template")
    wrap.innerHTML = html
    return wrap.content
  }

  onChipRemoved(event) {
    event.target.closest("[data-pending-reference]")?.remove()
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
