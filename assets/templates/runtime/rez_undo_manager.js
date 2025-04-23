// Obvious deficiencies:
// We don't consider what happens if an element gets removed, we should bring
// it back during undo.
class RezUndoManager {
  #changeList;
  #performingUndo;  // Flag to track if we're currently in an undo operation

  constructor() {
    this.reset();
  }

  reset() {
    this.#changeList = [];
    this.#performingUndo = false;
  }

  get canUndo() {
    return !this.#performingUndo && this.#changeList.length > 0;
  }

  get historySize() {
    return this.#changeList.length;
  }

  get curChange() {
    return this.#changeList.length > 0 ? this.#changeList.at(-1) : null;
  }

  get performingUndo() {
    return this.#performingUndo;
  }

  startChange() {
    // Don't start a new change record if we're in the middle of an undo operation
    if(!this.#performingUndo) {
      this.#changeList.push([]);
    }
  }

  recordNewElement(elemId) {
    if(!this.#performingUndo) {
      this.curChange?.unshift({
        changeType: "newElement",
        elemId: elemId
      });
    }
  }

  /**
   * Discard the most recent change. This is used during an undo when the event
   * the triggers the undo has started a new change.
   */
  #discardChange() {
    this.#changeList.pop();
  }

  recordRemoveElement(elem) {
    if(!this.#performingUndo) {
      this.curChange?.unshift({
        changeType: "removeElement",
        elem: elem
      });
    }
  }

  recordAttributeChange(elemId, attrName, oldValue) {
    if(!this.#performingUndo) {
      this.curChange?.unshift({
        changeType: "setAttribute",
        elemId: elemId,
        attrName: attrName,
        oldValue: oldValue
      });
    }
  }

  undo() {
    if(this.canUndo) {

      // Set flag to prevent recording changes during undo
      this.#performingUndo = true;

      try {
        console.log("RezUndoManager: Starting undo operation");

        this.#discardChange();
        const changes = this.#changeList.pop();

        console.log(`RezUndoManager: Undoing ${changes.length} changes`);
        console.dir(changes);

        // Apply all regular changes
        changes.forEach((change) => {
          if (change.changeType === "newElement") {
            this.#undoNewElement(change);
          } else if (change.changeType === "setAttribute") {
            this.#undoSetAttribute(change);
          } else if (change.changeType === "removeElement") {
            this.#undoRemoveElement(change);
          } else {
            throw new Error(`Unknown change type: ${change.changeType}`);
          }
        });

      } finally {
        // Clear the flag when we're done
        this.#performingUndo = false;
      }
    }
  }

  #undoNewElement({elemId}) {
    $(elemId, true).unmap();
  }

  #undoRemoveElement({elem}) {
    $game.addGameObject(elem);
  }

  #undoSetAttribute({elemId, attrName, oldValue}) {
    $(elemId, true).setAttribute(attrName, oldValue);
  }
}

window.Rez.RezUndoManager = RezUndoManager;
