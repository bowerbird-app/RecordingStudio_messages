import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recipients", "chipTemplate"]

  connect() {
    this.onChipRemoved = this.onChipRemoved.bind(this)
    this.hidePicked = this.hidePicked.bind(this)
    this.element.addEventListener("chip:removed", this.onChipRemoved)
    this.element.addEventListener("turbo:frame-load", this.hidePicked)
  }

  disconnect() {
    this.element.removeEventListener("chip:removed", this.onChipRemoved)
    this.element.removeEventListener("turbo:frame-load", this.hidePicked)
  }

  search() {
    if (this.searchTimer) window.clearTimeout(this.searchTimer)
    this.searchTimer = window.setTimeout(() => {
      this.element.querySelector("form[data-turbo-frame]")?.requestSubmit()
    }, 200)
  }

  keydown(event) {
    const options = this.visibleOptions()
    if (!options.length) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.moveActive(1, options)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.moveActive(-1, options)
    } else if (event.key === "Enter" && this.activeOption(options)) {
      event.preventDefault()
      this.activeOption(options).click()
    }
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
    this.hidePicked()
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
    this.hidePicked()
  }

  hidePicked() {
    const keys = this.existingKeys()
    this.element.querySelectorAll("[data-contact-key]").forEach((node) => {
      node.classList.toggle("hidden", keys.includes(node.dataset.contactKey))
    })
    const list = this.element.querySelector("[data-contact-key]")?.closest("ul, ol")
    if (list) list.classList.toggle("hidden", this.visibleOptions().length === 0)
  }

  visibleOptions() {
    return Array.from(this.element.querySelectorAll("[data-contact-key]")).filter(
      (node) => !node.classList.contains("hidden")
    )
  }

  activeOption(options) {
    return options.find((node) => node.getAttribute("aria-selected") === "true") || null
  }

  moveActive(step, options) {
    const current = options.findIndex((node) => node.getAttribute("aria-selected") === "true")
    const next = current < 0 ? 0 : (current + step + options.length) % options.length
    options.forEach((node, index) => {
      node.setAttribute("aria-selected", index === next ? "true" : "false")
    })
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
