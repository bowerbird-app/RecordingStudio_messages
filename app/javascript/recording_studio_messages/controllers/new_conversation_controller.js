import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recipients", "chipTemplate"]

  connect() {
    this.onChipRemoved = this.onChipRemoved.bind(this)
    this.element.addEventListener("chip:removed", this.onChipRemoved)
  }

  disconnect() {
    this.element.removeEventListener("chip:removed", this.onChipRemoved)
  }

  search() {
    if (this.searchTimer) window.clearTimeout(this.searchTimer)
    this.searchTimer = window.setTimeout(() => {
      this.element.querySelector("form[data-turbo-frame]")?.requestSubmit()
    }, 200)
  }

  add(event) {
    const button = event.currentTarget
    const type = button.dataset.type
    const id = button.dataset.id
    const name = button.dataset.name
    if (!type || !id || !this.hasRecipientsTarget) return
    if (this.existingKeys().includes(`${type}:${id}`)) return

    const wrap = document.createElement("div")
    wrap.dataset.pendingRecipient = "true"
    wrap.dataset.recipientKey = `${type}:${id}`
    wrap.className = "inline-flex"
    wrap.append(this.hiddenInput("type", type))
    wrap.append(this.hiddenInput("id", id))
    wrap.append(this.chipFor(name))
    this.recipientsTarget.append(wrap)
  }

  chipFor(name) {
    if (!this.hasChipTemplateTarget) return document.createTextNode(name || "")

    const html = this.chipTemplateTarget.innerHTML.replaceAll("__TITLE__", name || "")
    const wrap = document.createElement("template")
    wrap.innerHTML = html
    return wrap.content
  }

  onChipRemoved(event) {
    event.target.closest("[data-pending-recipient]")?.remove()
  }

  existingKeys() {
    return Array.from(this.recipientsTarget.querySelectorAll("[data-recipient-key]")).map(
      (node) => node.dataset.recipientKey
    )
  }

  hiddenInput(field, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = `recipients[][${field}]`
    input.value = value
    return input
  }
}
