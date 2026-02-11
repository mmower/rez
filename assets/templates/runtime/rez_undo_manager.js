//-----------------------------------------------------------------------------
// Undo Manager
//-----------------------------------------------------------------------------

/**
 * @class RezUndoManager
 * @category Utilities
 * @description Manages undo functionality by tracking changes to game state.
 *
 * The undo manager records changes made during each turn/action and allows
 * reverting to previous states. It tracks:
 * - Attribute changes on game elements
 * - Newly created elements
 * - Removed elements
 * - View state changes
 *
 * Changes are grouped into "change records" that represent a single undoable
 * action. When undo is triggered, all changes in the most recent record are
 * reverted together.
 *
 * The manager maintains a fixed-size history (default 16 records) to limit
 * memory usage. Older records are automatically discarded when the limit
 * is reached.
 *
 * Note: The undo manager automatically ignores changes made during an undo
 * operation to prevent infinite loops.
 *
 * @example
 * // Undo is typically triggered via game events
 * if($game.undoManager.canUndo) {
 *   $game.undoManager.undo();
 * }
 */
class RezUndoManager {
  /** @type {Array<Array>} */
  #changeList;
  /** @type {number} */
  #maxSize;
  /** @type {boolean} */
  #performingUndo;

  /**
   * @function constructor
   * @memberof RezUndoManager
   * @description Creates a new RezUndoManager.
   *
   * @param {number} [maxSize=16] - Maximum number of change records to keep
   */
  constructor(maxSize = 16) {
    this.#maxSize = maxSize;
    this.reset();
  }

  /**
   * Resets the undo manager, clearing all history.
   */
  reset() {
    this.#changeList = [];
    this.#performingUndo = false;
  }

  /**
   * Whether an undo operation is possible.
   *
   * Returns false if currently performing an undo or if history is empty.
   *
   * @type {boolean}
   */
  get canUndo() {
    return !this.#performingUndo && this.#changeList.length > 0;
  }

  /**
   * The number of change records in history.
   * @type {number}
   */
  get historySize() {
    return this.#changeList.length;
  }

  /**
   * The current (most recent) change record, or null if empty.
   * @type {Array|null}
   */
  get curChange() {
    return this.#changeList.length > 0 ? this.#changeList.at(-1) : null;
  }

  /**
   * Whether an undo operation is currently in progress.
   * @type {boolean}
   */
  get performingUndo() {
    return this.#performingUndo;
  }

  /**
   * Starts a new change record.
   *
   * Call this at the beginning of each undoable action. All subsequent
   * recorded changes will be grouped into this record until the next
   * call to startChange().
   *
   * If the history is full, the oldest record is discarded.
   * Does nothing if an undo operation is in progress.
   */
  startChange() {
    // Don't start a new change record if we're in the middle of an undo operation
    if(!this.#performingUndo) {
      if(this.#changeList.length >= this.#maxSize) {
        this.#changeList.shift(); // Remove the first (oldest) element
      }
      this.#changeList.push([]);
    }
  }

  /**
   * Records the creation of a new element.
   *
   * When undone, the element will be unmapped (removed from the game).
   *
   * @param {string} elemId - The ID of the newly created element
   */
  recordNewElement(elemId) {
    if(!this.#performingUndo) {
      this.curChange?.unshift({
        changeType: "newElement",
        elemId: elemId
      });
    }
  }

  /**
   * Discards the most recent change record.
   *
   * Used during undo when the triggering event has already started
   * a new (empty) change record.
   *
   * @private
   */
  #discardChange() {
    this.#changeList.pop();
  }

  /**
   * Records the removal of an element.
   *
   * When undone, the element will be restored to the game.
   *
   * @param {Object} elem - The element being removed
   */
  recordRemoveElement(elem) {
    if(!this.#performingUndo) {
      this.curChange?.unshift({
        changeType: "removeElement",
        elem: elem
      });
    }
  }

  /**
   * Records an attribute change on an element.
   *
   * When undone, the attribute will be restored to its old value.
   *
   * @param {string} elemId - The ID of the element
   * @param {string} attrName - The name of the changed attribute
   * @param {*} oldValue - The previous value of the attribute
   */
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

  /**
   * Records a view state change.
   *
   * When undone, the view will be restored to its previous state.
   *
   * @param {RezView} view - A copy of the view state to restore
   */
  recordViewChange(view) {
    if(!this.#performingUndo) {
      this.curChange?.unshift({
        changeType: "view",
        view: view
      });
    }
  }

  /**
   * Undoes the most recent change record.
   *
   * Reverts all changes in the record in reverse order. Sets a flag
   * to prevent recording changes made during the undo.
   *
   * @param {boolean} [manualUndo=false] - If true, doesn't discard the current
   *   change record (used when undo is triggered manually rather than by an event)
   */
  undo(manualUndo = false) {
    if(this.canUndo) {

      // Set flag to prevent recording changes during undo
      this.#performingUndo = true;

      try {
        console.log("RezUndoManager: Starting undo operation");

        if(!manualUndo) {
          this.#discardChange();
        }
        const changes = this.#changeList.pop();

        console.log(`RezUndoManager: Undoing ${changes.length} changes`);
        console.dir(changes);

        // Apply all regular changes
        changes.forEach((change) => {
          if(change.changeType === "newElement") {
            this.#undoNewElement(change);
          } else if(change.changeType === "setAttribute") {
            this.#undoSetAttribute(change);
          } else if(change.changeType === "removeElement") {
            this.#undoRemoveElement(change);
          } else if(change.changeType === "view") {
            this.#undoViewChange(change);
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

  /**
   * Undoes the creation of a new element by removing it.
   *
   * @param {Object} change - The change record
   * @param {string} change.elemId - The element ID to remove
   * @private
   */
  #undoNewElement({elemId}) {
    $(elemId, true).unmap();
  }

  /**
   * Undoes the removal of an element by restoring it.
   *
   * @param {Object} change - The change record
   * @param {Object} change.elem - The element to restore
   * @private
   */
  #undoRemoveElement({elem}) {
    $game.addGameObject(elem);
  }

  /**
   * Undoes an attribute change by restoring the old value.
   *
   * @param {Object} change - The change record
   * @param {string} change.elemId - The element ID
   * @param {string} change.attrName - The attribute name
   * @param {*} change.oldValue - The value to restore
   * @private
   */
  #undoSetAttribute({elemId, attrName, oldValue}) {
    $(elemId, true).setAttribute(attrName, oldValue);
  }

  /**
   * Undoes a view change by restoring the previous view state.
   *
   * @param {Object} change - The change record
   * @param {RezView} change.view - The view state to restore
   * @private
   */
  #undoViewChange({view}) {
    $game.restoreView(view)
  }
}

window.Rez.RezUndoManager = RezUndoManager;
