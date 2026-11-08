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
   * @param {string} itemId - ID of the item that has this effect
   * @param {object} [location] - where the item is, when the effect comes from an
   * item in an inventory: `{inventory_id, slot_id, position}`
   * @returns {*} result of the apply event handler
   * @description Applies this effect to the specified object by running the
   * `on_apply` event handler with `{owner_id, item_id, inventory_id, slot_id, position}`
   */
  apply(ownerId, itemId, location = {}) {
    return this.runEvent("apply", {owner_id: ownerId, item_id: itemId, ...location});
  }

  /**
   * @function remove
   * @memberof RezEffect
   * @param {string} ownerId - ID of the object this effect is being removed from
   * @param {string} itemId - ID of the item that has this effect
   * @param {object} [location] - where the item was, when the effect came from an
   * item in an inventory: `{inventory_id, slot_id, position}`
   * @returns {*} result of the remove event handler
   * @description Removes this effect from the specified object by running the
   * `on_remove` event handler with `{owner_id, item_id, inventory_id, slot_id, position}`
   */
  remove(ownerId, itemId, location = {}) {
    return this.runEvent("remove", {owner_id: ownerId, item_id: itemId, ...location});
  }
}

window.Rez.RezEffect = RezEffect;
