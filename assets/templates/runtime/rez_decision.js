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

let decision_proto = {
  yes() {
    this.made = true;
    this.result = true;
    this.used_default = false;
    return this;
  },

  default_yes() {
    this.made = true;
    this.result = true;
    this.used_default = true;
  },

  no(reason = "none given") {
    this.made = true;
    this.result = false;
    this.reason = reason;
    this.used_default = false;
    return this;
  },

  no_and_hide(reason = "none given") {
    this.made = true;
    this.result = false;
    this.reason = reason;
    this.hidden = true;
    this.used_default = false;
    return this;
  },

  default_no(reason = "none given") {
    this.made = true;
    this.result = false;
    this.reason = reason;
    this.used_default = true;
  },

  get wasMade() {
    return this.made;
  },

  get usedDefault() {
    return this.used_default;
  },

  setData(key, value) {
    this.data[key] = value;
    return this;
  },

  get wasYes() {
    return this.result;
  },

  get wasNo() {
    return !this.result;
  },

  explain() {
    if (this.result) {
      return `Result was yes`;
    } else {
      if (this.hide) {
        return `Result was no (${this.reason}) and hide the decision`;
      } else {
        return `Result was no (${this.reason})`;
      }
    }
  },
};

function RezDecision(purpose, data = {}) {
  this.purpose = purpose;
  this.made = false;
  this.decision = false;
  this.hidden = false;
  this.reason = "";
  this.data = data;
  this.used_default = false;
}

RezDecision.prototype = decision_proto;
RezDecision.prototype.constructor = RezDecision;
window.Rez.Decision = RezDecision;
