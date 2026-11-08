//-----------------------------------------------------------------------------
// Slot
//-----------------------------------------------------------------------------

/**
 * @class RezSlot
 * @extends RezBasicObject
 * @category Elements
 * @description Represents a kind of place in an inventory. Each position of an
 * inventory (declared with a `@contains` block) names the slot it uses, and the slot
 * decides what the position accepts (`accepts`), how much it holds (`has_capacity`,
 * `capacity`), which other slots it excludes (`excludes`), and whether items in it
 * apply their effects (`apply_effects`). Several positions can use the same slot.
 *
 * A slot also receives the `insert` and `remove` events for items added to, or
 * removed from, any position that uses it.
 *
 * @see RezInventory
 */
class RezSlot extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezSlot
   * @param {string} id - unique identifier for this slot
   * @param {object} attributes - slot attributes from Rez compilation including capacity and restrictions
   * @description Creates a new inventory slot instance
   */
  constructor(id, attributes) {
    super("slot", id, attributes);
  }
}

window.Rez.RezSlot = RezSlot;
