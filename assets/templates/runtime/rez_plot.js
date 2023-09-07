//-----------------------------------------------------------------------------
// Plot
//-----------------------------------------------------------------------------

let plot_proto = {
  __proto__: basic_object,

  isActive() {
    return this.stage > 0;
  },

  isComplete() {
    return this.stage === this.stages;
  },

  advance() {
    if (this.cur_stage < this.stages) {
      this.cur_stage += 1;
      this.runEvent("advance", {});
    }
  },
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
