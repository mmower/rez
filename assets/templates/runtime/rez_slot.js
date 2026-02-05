//-----------------------------------------------------------------------------
// Slot
//-----------------------------------------------------------------------------

/**
 * @class RezSlot
 * @extends RezBasicObject
 * @category Elements
 * @description Represents an inventory slot in the Rez game engine. Slots define
 * compartments within inventories where items can be stored. Each slot has properties
 * like capacity, item type restrictions, and accessor names for template binding.
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
