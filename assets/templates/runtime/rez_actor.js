//-----------------------------------------------------------------------------
// Actor
//-----------------------------------------------------------------------------

let actor_proto = {
  __proto__: basic_object,

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
  checkItem(inventory_id, slot_id, item_id) {
    const decision = new RezDecision("Filter Item");
    decision.default_yes();
    if (this.willHandleEvent("accept_item")) {
      this.runEvent("accept_item", {
        decision: decision,
        inventory_id: inventory_id,
        slot_id: slot_id,
        item_id: item_id,
      });
    }
    return decision;
  },

  /**
   * @function elementInitializer
   * @memberof RezActor
   * @description initializes properties of RezActor
   */
  elementInitializer() {
    if (this.hasAttribute("initial_location")) {
      this.move_to(this.getAttributeValue("initial_location"));
    }
  },

  /**
   * @function moveTo
   * @memberof RezActor
   * @param {string} to_location_id
   * @description moves this actor to a new location
   */
  move_to(to_location_id) {
    console.log("Moving |" + this.id + "| to |" + to_location_id + "|");

    if (this.hasAttribute("location_id")) {
      const from_location_id = this.getAttributeValue("location_id");
      this.runEvent("leave", { location_id: from_location_id });
      const from_location = $(from_location_id);
      from_location.runEvent("leave", { actor_id: this.id });
    }

    this.setAttribute("location_id", to_location_id);
    this.runEvent("enter", { location_id: to_location_id });
    const to_location = $(to_location_id);
    to_location.runEvent("enter", { actor_id: this.id });
  },
};

/**
 * @class
 * @param {string} id
 * @param {object} attributes
 */
function RezActor(id, attributes) {
  this.id = id;
  this.auto_id_idx = 0;
  this.game_object_type = "actor";
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezActor.prototype = actor_proto;
RezActor.prototype.constructor = RezActor;
window.Rez.Actor = RezActor;
