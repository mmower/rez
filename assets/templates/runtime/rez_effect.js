//-----------------------------------------------------------------------------
// Effect
//-----------------------------------------------------------------------------

/**
 * @class RezEffect
 * @extends RezBasicObject
 * @category Elements
 * @description Represents an effect in the Rez game engine. Effects are typically
 * applied to or removed from objects when items are equipped, consumed, or used.
 * They can modify object attributes, add temporary abilities, or trigger events.
 */
class RezEffect extends RezBasicObject {
  /**
   * @function constructor
   * @memberof RezEffect
   * @param {string} id - unique identifier for this effect
   * @param {object} attributes - effect attributes from Rez compilation
   * @description Creates a new effect instance
   */
  constructor(id, attributes) {
    super("effect", id, attributes);
  }

  /**
   * @function apply
   * @memberof RezEffect
   * @param {string} ownerId - ID of the object this effect is being applied to
   * @param {string} slotId - ID of the inventory slot where the item is located
   * @param {string} itemId - ID of the item that has this effect
   * @returns {*} result of the apply event handler
   * @description Applies this effect to the specified object by running the apply event handler
   */
  apply(ownerId, slotId, itemId) {
    return this.runEvent("apply", {owner_id: ownerId, slot_id: slotId, item_id: itemId});
  }

  /**
   * @function remove
   * @memberof RezEffect
   * @param {string} ownerId - ID of the object this effect is being removed from
   * @param {string} slotId - ID of the inventory slot where the item is located
   * @param {string} itemId - ID of the item that has this effect
   * @returns {*} result of the remove event handler
   * @description Removes this effect from the specified object by running the remove event handler
   */
  remove(ownerId, slotId, itemId) {
    return this.runEvent("remove", {owner_id: ownerId, slot_id: slotId, item_id: itemId});
  }
}

window.Rez.RezEffect = RezEffect;
