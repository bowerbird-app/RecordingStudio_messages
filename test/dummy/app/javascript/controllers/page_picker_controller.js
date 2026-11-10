import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  search() {
    if (this.searchTimer) window.clearTimeout(this.searchTimer)
    this.searchTimer = window.setTimeout(() => {
      this.element.querySelector("form")?.requestSubmit()
    }, 200)
  }

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
  }
}
