//-----------------------------------------------------------------------------
// DynamicLink
//-----------------------------------------------------------------------------

class RezDynamicLink {
  #card;
  #inactiveClass;
  #choosen;
  #display;
  #markup;

  constructor(card) {
    this.#card = card;
    this.#inactiveClass = "inactive";
    this.#choosen = false;
    this.#display = true;
    this.#markup = "<strong>No text for dynamic link</strong>";
  }

  get card() {
    return this.#card;
  }

  get inactiveClass() {
    return this.#inactiveClass;
  }

  get choosen() {
    return this.#choosen;
  }

  get display() {
    return this.#display;
  }

  get markup() {
    return this.#markup;
  }

  allow(response, targetId) {
    this.#choosen = true;
    if (typeof response === "function") {
      this.#markup = response();
    } else {
      this.#markup = `<a href="javascript:void(0)" data-event="card" data-target="${targetId}">${response}</a>`;
    }
  }

  deny(text, asLink) {
    this.#choosen = true;

    if(asLink == null || asLink) {
      this.#markup = `<a href="javascript:void(0)" class="${this.inactiveClass}">${text}</a>`;
    } else {
      this.#markup = `<span class="${this.inactiveClass}">${text}</span>`;
    }
  }

  hide() {
    this.#choosen = true;
    this.#display = false;
  }
}

window.Rez.RezDynamicLink = RezDynamicLink;
