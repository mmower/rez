//-----------------------------------------------------------------------------
// Plot
//-----------------------------------------------------------------------------

class RezPlot extends RezBasicObject {
  constructor(id, attributes) {
    super("plot", id, attributes);
  }

  get isComplete() {
    return this.stage == this.stages;
  }

  advance() {
    if(this.stage < this.stages) {
      this.stage += 1;
      this.runEvent("advance", {});
    }
  }
}

window.Rez.RezPlot = RezPlot;
