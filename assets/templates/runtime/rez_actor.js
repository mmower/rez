//-----------------------------------------------------------------------------
// Actor
//-----------------------------------------------------------------------------

/**
 * @class RezActor
 * @extends RezBasicObject
 * @category Elements
 * @description Represents an actor in the Rez game engine. Actors are game
 * entities that can hold inventories, check items, and participate in game events.
 */
class RezActor extends RezBasicObject {
  constructor(id, attributes) {
    super("actor", id, attributes);
  }

  /**
   * @function checkItem
   * @memberof RezActor
   * @param {string} inventoryId id of an inventory this actor owns
   * @param {string} slotId id of the `@slot` the position uses
   * @param {string} position name of the position
   * @param {string} itemId
   * @returns {RezDecision}
   * @description When an item is about to be added to a position of an inventory
   * this actor owns, runs the actor's `on_accept_item` event handler so the actor
   * can refuse it.
   *
   * The params passed to the event handler are:
   * - decision
   * - inventory_id
   * - slot_id
   * - position
   * - item_id
   *
   * The decision defaults to yes. Call `params.decision.no(reason)` to refuse.
   */
  checkItem(inventoryId, slotId, position, itemId) {
    const decision = new RezDecision("Filter Item");
    decision.defaultYes();
    if(this.willHandleEvent("accept_item")) {
      this.runEvent("accept_item", {
        decision: decision,
        inventory_id: inventoryId,
        slot_id: slotId,
        position: position,
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
    if(this.hasAttribute("initial_location")) {
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

    if(this.hasAttribute("location_id")) {
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
