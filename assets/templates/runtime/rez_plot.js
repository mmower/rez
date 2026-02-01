//-----------------------------------------------------------------------------
// Plot
//-----------------------------------------------------------------------------

/**
 * @class RezPlot
 * @extends RezBasicObject
 * @description Tracks the progression of a storyline or quest through discrete stages.
 *
 * A plot represents a linear sequence of stages that the player advances through.
 * Each plot has a current stage and a total number of stages. When the current
 * stage equals the total stages, the plot is considered complete.
 *
 * Plots fire events at key lifecycle points:
 * - "start" when the plot begins (first advance from stage 0)
 * - "advance" each time the stage increases (with `{stage}` param)
 * - "complete" when the final stage is reached
 *
 * Use plots for:
 * - Main story progression
 * - Side quests with multiple steps
 * - Tutorial sequences
 * - Achievement tracking
 *
 * @example
 * // Define in Rez
 * @plot main_quest {
 *   stage: 0
 *   stages: 5
 *   on_advance: (plot, evt) => {
 *     console.log(`Advanced to stage ${evt.stage}`);
 *   }
 * }
 *
 * @example
 * // Advance the plot at runtime
 * const quest = $("main_quest");
 * if (!quest.isComplete) {
 *   quest.advance();
 * }
 */
class RezPlot extends RezBasicObject {
  /**
   * Creates a new RezPlot.
   *
   * @param {string} id - Unique identifier for this plot
   * @param {Object} attributes - Initial attributes (should include `stage` and `stages`)
   */
  constructor(id, attributes) {
    super("plot", id, attributes);
  }

  /**
   * Whether this plot has reached its final stage.
   * @type {boolean}
   */
  get isComplete() {
    return this.stage == this.stages;
  }

  /**
   * Advances the plot to the next stage if not already complete.
   *
   * Increments the `stage` attribute and fires appropriate events:
   * - "start" on the first advance (from stage 0 to 1)
   * - "advance" with `{stage}` param on every advance
   * - "complete" when reaching the final stage
   *
   * Does nothing if the plot is already complete.
   *
   * @fires start - When advancing from stage 0
   * @fires advance - On every advance, with `{stage}` param
   * @fires complete - When reaching the final stage
   */
  advance() {
    if(this.stage < this.stages) {
      const wasAtStart = this.stage === 0;
      this.stage += 1;

      if(wasAtStart) {
        this.runEvent("start", {});
      }

      this.runEvent("advance", {stage: this.stage});

      if(this.isComplete) {
        this.runEvent("complete", {});
      }
    }
  }
}

window.Rez.RezPlot = RezPlot;
