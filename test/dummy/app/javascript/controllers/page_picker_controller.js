import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  insert(event) {
    const button = event.currentTarget
    window.dispatchEvent(
      new CustomEvent("messages:composer-insert", {
        bubbles: true,
        detail: {
          text: [button.dataset.title, button.dataset.url].filter(Boolean).join("\n"),
          reference: {
            recording_id: button.dataset.recordingId,
            title: button.dataset.title,
            url: button.dataset.url
          }
        }
      })
    )

    const closeButton = this.element.closest("[data-controller~='flat-pack--modal']")
      ?.querySelector("[data-action='flat-pack--modal#close']")
    closeButton?.click()
  }
}
