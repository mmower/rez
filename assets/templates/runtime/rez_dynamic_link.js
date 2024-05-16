//-----------------------------------------------------------------------------
// DynamicLink
//-----------------------------------------------------------------------------

function RezDynamicLink(card) {
  this.game_object_type = "dynamic_link";
  this.properties_to_archive = [];
  this.changed_attributes = [];
  this.card = card;
}

RezDynamicLink.prototype = {
  constructor: RezDynamicLink,

  inactive_class: "inactive",
  choosen: false,
  display: true,
  markup: "<strong>No text for dynamic link</strong>",

  allow(response, target_id) {
    this.choosen = true;
    if (typeof response == "function") {
      this.markup = response();
    } else {
      this.markup = `<a href="javascript:void(0)" data-event="card" data-target="${target_id}">${response}</a>`;
    }
  },

  deny(text, as_link) {
    this.choosen = true;

    if (as_link == null || as_link) {
      this.markup =
        '<a href="javascript:void(0)" class="' +
        this.inactive_class +
        '">' +
        text +
        "</a>";
    } else {
      this.markup =
        '<span class="' + this.inactive_class + '">' + text + "</span>";
    }
  },

  hide() {
    this.choosen = true;
    this.display = false;
  },
};

window.Rez.RezDynamicLink = RezDynamicLink;
