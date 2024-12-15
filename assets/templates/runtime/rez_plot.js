//-----------------------------------------------------------------------------
// Plot
//-----------------------------------------------------------------------------

class RezPlot extends RezBasicObject {
  constructor(id, attributes) {
    super("plot", id, attributes);
  }

  get isActive() {
    return this.cur_stage > 0;
  }

  get isComplete() {
    return this.cur_stage == this.stages;
  }

  advance() {
    if(this.cur_stage < this.stages) {
      this.cur_stage += 1;
      this.runEvent("advance", {});
    }
  }
}

window.Rez.RezPlot = RezPlot;
