//-----------------------------------------------------------------------------
// DynamicLink
//-----------------------------------------------------------------------------

/**
 * @class RezDynamicLink
 * @description Represents a conditional link that can be shown, hidden, or disabled based on game state.
 *
 * Dynamic links are used in templates to create links whose appearance and behavior
 * depend on runtime conditions. A link can be:
 * - Allowed: Shown as a clickable link that triggers an action
 * - Denied: Shown as inactive/greyed out text (optionally as a non-clickable link)
 * - Hidden: Not displayed at all
 *
 * This is typically used for choice-based navigation where some options may not
 * be available based on player stats, inventory, or story progress.
 *
 * @example
 * // In a card's event handler
 * const link = new RezDynamicLink(this);
 * if (player.hasKey) {
 *   link.allow("Open the door", "card_behind_door");
 * } else {
 *   link.deny("The door is locked", false);
 * }
 * return link.markup;
 */
class RezDynamicLink {
  /** @type {Object} */
  #card;
  /** @type {string} */
  #inactiveClass;
  /** @type {boolean} */
  #choosen;
  /** @type {boolean} */
  #display;
  /** @type {string} */
  #markup;

  /**
   * Creates a new dynamic link.
   *
   * @param {Object} card - The card this link belongs to
   */
  constructor(card) {
    this.#card = card;
    this.#inactiveClass = "inactive";
    this.#choosen = false;
    this.#display = true;
    this.#markup = "<strong>No text for dynamic link</strong>";
  }

  /**
   * The card this link belongs to.
   * @type {Object}
   */
  get card() {
    return this.#card;
  }

  /**
   * The CSS class applied to inactive/denied links.
   * @type {string}
   */
  get inactiveClass() {
    return this.#inactiveClass;
  }

  /**
   * Whether a choice has been made (allow, deny, or hide).
   * @type {boolean}
   */
  get choosen() {
    return this.#choosen;
  }

  /**
   * Whether this link should be displayed.
   * @type {boolean}
   */
  get display() {
    return this.#display;
  }

  /**
   * The HTML markup for this link.
   * @type {string}
   */
  get markup() {
    return this.#markup;
  }

  /**
   * Makes this link active and clickable.
   *
   * @param {string|Function} response - Either the link text, or a function that returns custom markup
   * @param {string} targetId - The ID of the target card to navigate to when clicked
   *
   * @example
   * // Simple text link
   * link.allow("Go north", "card_north_room");
   *
   * @example
   * // Custom markup via function
   * link.allow(() => `<a href="#" data-event="custom">Custom action</a>`, null);
   */
  allow(response, targetId) {
    this.#choosen = true;
    if (typeof response === "function") {
      this.#markup = response();
    } else {
      this.#markup = `<a href="javascript:void(0)" data-event="card" data-target="${targetId}">${response}</a>`;
    }
  }

  /**
   * Makes this link inactive/disabled.
   *
   * The link text is shown but cannot be clicked. Useful for showing
   * options that exist but are currently unavailable.
   *
   * @param {string} text - The text to display
   * @param {boolean} [asLink=true] - If true, renders as an inactive link; if false, renders as a span
   *
   * @example
   * // Show as greyed-out link
   * link.deny("Locked door (requires key)");
   *
   * @example
   * // Show as plain text
   * link.deny("Not available", false);
   */
  deny(text, asLink) {
    this.#choosen = true;

    if(asLink == null || asLink) {
      this.#markup = `<a href="javascript:void(0)" class="${this.inactiveClass}">${text}</a>`;
    } else {
      this.#markup = `<span class="${this.inactiveClass}">${text}</span>`;
    }
  }

  /**
   * Hides this link completely.
   *
   * The link will not be displayed at all. Use this when an option
   * should not even be visible to the player.
   *
   * @example
   * // Hide the secret passage unless discovered
   * if (!player.foundSecretPassage) {
   *   link.hide();
   * }
   */
  hide() {
    this.#choosen = true;
    this.#display = false;
  }
}

window.Rez.RezDynamicLink = RezDynamicLink;
