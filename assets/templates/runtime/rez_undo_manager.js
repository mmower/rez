// Obvious deficiencies:
// We don't consider what happens if an element gets removed, we should bring
// it back during undo.
class RezUndoManager {
  #changeList;
  #inUndo;  // Flag to track if we're currently in an undo operation

  constructor() {
    this.reset();
  }

  reset() {
    this.#changeList = [];
    this.#inUndo = false;
  }

  get canUndo() {
    return !this.#inUndo && this.#changeList.length > 0;
  }

  get historySize() {
    return this.#changeList.length;
  }

  get curChange() {
    return this.#changeList.length > 0 ? this.#changeList[this.#changeList.length - 1] : null;
  }

  get inUndo() {
    return this.#inUndo;
  }

  startChange() {
    // Don't start a new change record if we're in the middle of an undo operation
    if(this.#inUndo) {
      console.log("RezUndoManager: Skipping startChange during undo");
      return;
    }

    console.log("RezUndoManager: Starting change");
    this.#changeList.push([]);
  }

  recordNewElement(elemId) {
    if (this.#inUndo) return;

    this.curChange?.unshift({
      changeType: "newElement",
      elemId: elemId
    });
  }

  recordRemoveElement(elem) {
    if (this.#inUndo) return;

    this.curChange?.unshift({
      changeType: "removeElement",
      elem: elem
    });
  }

  recordAttributeChange(elemId, attrName, oldValue) {
    if (this.#inUndo) return;

    console.log(`RezUndoManager: record '${elemId}' changed '${attrName}' from '${oldValue}'`);
    this.curChange?.unshift({
      changeType: "setAttribute",
      elemId: elemId,
      attrName: attrName,
      oldValue: oldValue
    });
  }

  undo() {
    if (!this.canUndo) {
      console.log("RezUndoManager: Cannot undo - no more history");
      return;
    }

    // Set flag to prevent recording changes during undo
    this.#inUndo = true;

    try {
      console.log("RezUndoManager: Starting undo operation");
      const changes = this.#changeList.pop();

      // Skip empty change records
      if (changes.length === 0) {
        console.log("RezUndoManager: Skipping empty change record");
        // If this was an empty change, try again with the next one
        if (this.canUndo) {
          return this.undo();
        }
        return;
      }

      console.log(`RezUndoManager: Undoing ${changes.length} changes`);

      // Apply all regular changes
      changes.forEach((change) => {
        if (change.changeType === "newElement") {
          this.#undoNewElement(change);
        } else if (change.changeType === "setAttribute") {
          this.#undoSetAttribute(change);
        } else if (change.changeType === "removeElement") {
          this.#undoRemoveElement(change);
        } else {
          console.warn(`Unknown change type: ${change.changeType}`);
        }
      });

      // Ensure the view gets updated
      $game.updateView();

    } finally {
      // Clear the flag when we're done
      this.#inUndo = false;
    }
  }

  #undoNewElement({elemId}) {
    console.log(`RezUndoManager: Undo new element: ${elemId}`);
    const elem = $(elemId, true);
    elem.unmap();
  }

  #undoRemoveElement({elem}) {
    console.log(`RezUndoManager: Undo remove element: ${elem.id}`);
    $game.addGameObject(elem);
  }

  #undoSetAttribute({elemId, attrName, oldValue}) {
    console.log(`RezUndoManager: Undo set ${elemId} attribute ${attrName} -> ${oldValue}`);
    const elem = $(elemId, true);
    elem.setAttribute(attrName, oldValue, false);
  }
}

window.Rez.RezUndoManager = RezUndoManager;
