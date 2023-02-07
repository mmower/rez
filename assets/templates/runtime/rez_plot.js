//-----------------------------------------------------------------------------
// Plot
//-----------------------------------------------------------------------------

let plot_proto = {
  __proto__: basic_object,

  isActive() {
    return this.getAttribute("tick") > 0;
  },

  isComplete() {
    return this.getAttribute("tick") == this.getAttribute("ticks");
  },

  tick() {
    let curr_tick = this.getAttribute("tick");
    const max_ticks = this.getAttribute("ticks");
    if(curr_tick < max_ticks) {
      curr_tick += 1;
      this.setAttribute("tick", curr_tick);
      this.runEvent("tick", {});
    }
  }
};

function RezPlot(id, attributes) {
  this.id = id;
  this.game_object_type = "plot";
  this.status = 0;
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezPlot.prototype = plot_proto;
RezPlot.prototype.constructor = RezPlot;
window.Rez.Plot = RezPlot;
