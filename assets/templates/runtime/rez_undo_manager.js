function RezUndoManager() {
  this.prev_changes = [];
  this.changes = [];
}

RezUndoManager.prototype.newTurn = function () {
  this.prev_changes.push(this.changes);
  this.changes = [];
};

RezUndoManager.prototype.recordChange = function (
  el_id,
  attr_name,
  prev_value
) {
  this.changes.push({
    el_id: el_id,
    attr_name: attr_name,
    prev_value: prev_value,
  });
};

RezUndoManager.prototype.undo = function () {
  this.changes.forEach((change) => {
    const el = $(change.el_id);
    el.setAttribute(change.attr_name, change.prev_value, false);
  });

  if (this.prev_changes.length >= 1) {
    this.changes = this.prev_changes.pop();
  } else {
    this.changes = [];
  }
};

RezUndoManager.prototype.constructor = RezUndoManager;
window.Rez.UndoManager = RezUndoManager;
