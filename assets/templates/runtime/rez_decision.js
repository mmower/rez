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
    this.default = false;
    return this;
  },

  default_yes() {
    this.made = true;
    this.result = true;
    this.default = true;
  },

  no(reason = "none given") {
    this.made = true;
    this.result = false;
    this.reason = reason;
    this.default = false;
    return this;
  },

  default_no() {
    this.made = true;
    this.result = false;
    this.default = true;
  },

  wasMade() {
    return this.made;
  },

  usedDefault() {
    return this.default;
  },

  data() {
    return this.data;
  },

  setData(key, value) {
    this.data[key] = value;
    return this;
  },

  result() {
    return this.result;
  },

  purpose() {
    return this.purpose;
  },

  reason() {
    return this.reason;
  },
};

function RezDecision(purpose, data = {}) {
  this.purpose = purpose;
  this.made = false;
  this.decision = false;
  this.reason = "";
  this.data = data;
  this.default = false;
}

RezDecision.prototype = decision_proto;
RezDecision.prototype.constructor = RezDecision;
window.Rez.Decision = RezDecision;
