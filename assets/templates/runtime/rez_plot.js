//-----------------------------------------------------------------------------
// Plot
//-----------------------------------------------------------------------------

function RezPlot(id, attributes) {
  this.id = id;
  this.game_object_type = "plot";
  this.status = 0;
  this.attributes = attributes;
  this.properties_to_archive = [];
  this.changed_attributes = [];
}

RezPlot.prototype = {
  __proto__: basic_object,
  constructor: RezPlot,

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
