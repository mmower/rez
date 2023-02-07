//-----------------------------------------------------------------------------
// DynamicLink
//-----------------------------------------------------------------------------

let dynamic_link_proto = {
  inactive_class: "inactive",
  choosen: false,
  display: true,
  markup: "<strong>No text for dynamic link</strong>",
  card: null,

  game() {
    return this.card.game;
  },

  allow(response, target_id) {
    if(typeof(response) != "function" && target_id == null ) {
      throw new Error("Unable to build dynamic link, no target specified.");
    } else if(this.game().getTarget(target_id) == null) {
      throw new Error("Unable to build dynamic link, no card or scene '" + target_id + "' exists in the game.");
    }

    this.choosen = true;

    if(typeof(response) == "function") {
      this.markup = response();
    } else {
      this.markup = "<a href=\"javascript:void(0)\" data-target=\"" + target_id + "\">" + response + "</a>";
    }
  },

  deny(text, as_link) {
    this.choosen = true;

    if(as_link == null || as_link) {
      this.markup = "<a href=\"javascript:void(0)\" class=\""+this.inactive_class+"\">" + text + "</a>";
    } else {
      this.markup = "<span class=\"" + this.inactive_class + "\">" + text + "</span>";
    }
  },

  hide() {
    this.choosen = true;
    this.display = false;
  },

};

function RezDynamicLink(card) {
  this.card = card;
  this.game_object_type = "dynamic_link";
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezDynamicLink.prototype = dynamic_link_proto;
RezDynamicLink.prototype.constructor = RezDynamicLink;
window.Rez.DynamicLink = RezDynamicLink;
