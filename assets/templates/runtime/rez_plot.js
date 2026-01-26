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
 * Plots fire an "advance" event each time they progress, allowing authors to
 * trigger side effects like unlocking new areas, updating NPC dialogue, or
 * granting rewards.
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
 *     console.log(`Advanced to stage ${plot.stage}`);
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
   * Increments the `stage` attribute and fires an "advance" event.
   * Does nothing if the plot is already complete.
   *
   * @fires advance
   */
  advance() {
    if(this.stage < this.stages) {
      this.stage += 1;
      this.runEvent("advance", {});
    }
  }
}

window.Rez.RezPlot = RezPlot;
