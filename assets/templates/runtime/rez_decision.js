//-----------------------------------------------------------------------------
// Decision
//-----------------------------------------------------------------------------

/*
 * RezDecision is an object type that can be passed to user-written filters.
 * Conceptually it's a simplified abstraction of the RezDynamicLink.
 *
 * When given a decision the caller should call either of `yes()` or
 * `no(reason)` to instruct the calling code about what to do.
 */
class RezDecision {
  #purpose;
  #made;
  #result;
  #hidden;
  #reason;
  #data;
  #used_default;

  constructor(purpose, data = {}) {
    this.#purpose = purpose;
    this.#made = false;
    this.#result = false;
    this.#hidden = false;
    this.#reason = "";
    this.#data = data;
    this.#used_default = false;
  }

  get purpose() {
    return this.#purpose;
  }

  get wasMade() {
    return this.#made;
  }

  get result() {
    return this.#result;
  }

  get wasYes() {
    return this.#result;
  }

  get wasNo() {
    return !this.wasYes;
  }

  get isHidden() {
    return this.#hidden;
  }

  get reason() {
    return this.#reason;
  }

  get data() {
    return this.#data;
  }

  get usedDefault() {
    return this.#used_default;
  }

  yes() {
    this.#made = true;
    this.#result = true;
    this.#used_default = false;
    return this;
  }

  defaultYes() {
    this.#made = true;
    this.#result = true;
    this.#used_default = true;
    return this;
  }

  no(reason = "none given") {
    this.#made = true;
    this.#result = false;
    this.#reason = reason;
    this.#used_default = false;
    return this;
  }

  hide() {
    this.#made = true;
    this.#result = false;
    this.#reason = "hidden";
    this.#hidden = true;
    this.#used_default = false;
  }

  defaultNo(reason = "none given") {
    this.#made = true;
    this.#result = false;
    this.#reason = reason;
    this.#used_default = true;
    return this;
  }

  setData(key, value) {
    this.#data[key] = value;
    return this;
  }

  explain() {
    if (this.result) {
      return `Result was yes`;
    } else {
      if (this.hidden) {
        return `Result was no (${this.reason}) and hide the decision`;
      } else {
        return `Result was no (${this.reason})`;
      }
    }
  }
}
