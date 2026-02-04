//-----------------------------------------------------------------------------
// Actor
//-----------------------------------------------------------------------------

class RezActor extends RezBasicObject {
  constructor(id, attributes) {
    super("actor", id, attributes);
  }

  /**
   * @function checkItem
   * @memberof RezActor
   * @param {string} inventory_id
   * @param {string} slot_id
   * @param {string} item_id
   * @returns {RezDecision}
   * @description when it is attempted to put the specified item into the
   * specified inventory slot, call this actors 'on_accept_item' event handler
   * to give the actor the opportunity to decide whether to accept it or not.
   *
   * The params passed to the event handler are:
   * decision
   * inventory_id
   * slot_id
   * item_id
   *
   * The RezDecision will default to yes. The event handler should return an
   * appropriate RezDecision.
   */
  checkItem(inventoryId, slotId, itemId) {
    const decision = new RezDecision("Filter Item");
    decision.defaultYes();
    if (this.willHandleEvent("accept_item")) {
      this.runEvent("accept_item", {
        decision: decision,
        inventory_id: inventoryId,
        slot_id: slotId,
        item_id: itemId,
      });
    }
    return decision;
  }

  /**
   * @function elementInitializer
   * @memberof RezActor
   * @description initializes properties of RezActor
   */
  elementInitializer() {
    if (this.hasAttribute("initial_location")) {
      this.moveTo(this.getAttributeValue("initial_location"));
    }
  }

  /**
   * @function moveTo
   * @memberof RezActor
   * @param {string} to_location_id
   * @description moves this actor to a new location
   */
  moveTo(destLocationId) {
    console.log(`Moving |${this.id}| to |${destLocationId}|`);

    if (this.hasAttribute("location_id")) {
      const fromLocationId = this.getAttributeValue("location_id");
      this.runEvent("leave", {location_id: fromLocationId});
      const fromLocation = $(fromLocationId);
      fromLocation.runEvent("leave", {actor_id: this.id});
    }

    this.setAttribute("location_id", destLocationId);
    this.runEvent("enter", {location_id: destLocationId});
    const destLocation = $(destLocationId);
    destLocation.runEvent("enter", {actor_id: this.id});
  }
}

window.Rez.RezActor = RezActor;
