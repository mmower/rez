function RezUndoManager() {
  this.prev_changes = [];
  this.changes = [];
}

RezUndoManager.prototype = {
  constructor: RezUndoManager,

  newTurn() {
    this.prev_changes.push(this.changes);
    this.changes = [];
  },

  recordChange(el_id, attr_name, prev_value) {
    this.changes.push({
      el_id: el_id,
      attr_name: attr_name,
      prev_value: prev_value,
    });
  },

  undo() {
    this.changes.forEach((change) => {
      const el = $(change.el_id);
      el.setAttribute(change.attr_name, change.prev_value, false);
    });

    if (this.prev_changes.length >= 1) {
      this.changes = this.prev_changes.pop();
    } else {
      this.changes = [];
    }
  }
};
