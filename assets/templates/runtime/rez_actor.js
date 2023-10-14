//-----------------------------------------------------------------------------
// Actor
//-----------------------------------------------------------------------------

let actor_proto = {
  __proto__: basic_object,

  /*
   * Give the actor an opportunity to respond to an on_accept_item callback
   * and return a RezDecision with the result. By default items are accepted.
   */
  checkItem(inventory_id, slot_id, item_id) {
    const decision = new RezDecision("Filter Item");
    decision.default_yes();
    if (this.willHandleEvent("accept_item")) {
      this.runEvent("accept_item", {
        decision: decision,
        inventory_id: inventory_id,
        item_id: item_id,
      });
    }
    return decision;
  },

  elementInitializer() {
    if (this.hasAttribute("initial_location")) {
      this.move(this.getAttributeValue("initial_location"));
    }
  },

  move(to_location_id) {
    console.log("Moving |" + this.id + "| to |" + to_location_id + "|");

    if (this.hasAttribute("location")) {
      const from_location_id = this.getAttributeValue("location");
      this.runEvent("leave", { location_id: from_location_id });
      const from_location = $(from_location_id);
      from_location.runEvent("actor_leaves", { actor_id: this.id });
    }

    this.setAttribute("location", to_location_id);
    this.runEvent("enter", { location_id: to_location_id });
    const to_location = $(to_location_id);
    to_location.runEvent("actor_enters", { actor_id: this.id });
  },
};

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
