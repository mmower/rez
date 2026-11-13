//-----------------------------------------------------------------------------
// Roll
//-----------------------------------------------------------------------------

/**
 * @class RezRoll
 * @category Utilities
 * @description A dice roll built as a pipeline: roll a pool of dice, pass them
 * through a list of transformers, then pass the final value to an evaluator.
 *
 * - **Dice**: `number` dice with `sides` sides are rolled once into `rolls[0]`
 *   (also available as `dice`).
 * - **Transformers**: functions `(roll, value) => newValue`, applied in order.
 *   Each stage's output is appended to `rolls`, so every intermediate step can
 *   be inspected (e.g. `rolls[1]` is the kept dice after `keepHighest(2)`).
 *   Transformers can annotate `roll.flags` (e.g. `flags.critical`).
 * - **Evaluator**: a function `(final, roll) => result` that turns the last stage
 *   into a result (a boolean, an outcome name, or anything else).
 *
 * After a roll, the dice can be edited (`setDie`, `adjustDie`, `rerollDie`).
 * `recompute()` then re-runs the transformers and evaluator over the edited dice.
 * Any extra dice a transformer rolled (e.g. explosions) are replayed rather than
 * re-rolled, so only the player's edit changes the outcome. Every edit is
 * recorded in `edits`.
 *
 * Standard transformers and evaluators are static functions (`RezRoll.keepHighest`,
 * `RezRoll.sum`, `RezRoll.outcome`, ...). `RezRoll.twoD6`, `RezRoll.d20` and
 * `RezRoll.blades` are ready-made presets.
 *
 * `RezDieRoll` is unchanged; use it for simple `NdX+M` rolls.
 *
 * @example
 * // 2d6+1 must beat 8; advantage = 3d6 keep the best 2
 * const r = new RezRoll(3, 6, [RezRoll.keepHighest(2), RezRoll.critOnAll(), RezRoll.sum(1)],
 *                       RezRoll.beats(8));
 * r.roll();         // => true/false
 * r.dice;           // => e.g. [2, 6, 5]
 * r.rolls[1];       // => [5, 6] (the kept dice)
 * r.flags.critical; // => "success", "failure" or undefined
 *
 * @example
 * // The player spends a resource to turn the first die into a 6
 * r.setDie(0, 6, "spent luck");
 * r.recompute();
 * r.edits; // => [{action: "set", index: 0, from: 2, to: 6, reason: "spent luck"}]
 */
class RezRoll {
  #number;
  #sides;
  #dieFn;
  #rolls;
  #transformers;
  #evaluator;
  #result;
  #flags;
  #edits;
  #extraDice;
  #extraKeyed;
  #extraIdx;
  #transforming;

  /**
   * @function constructor
   * @memberof RezRoll
   * @description Creates a new roll. Nothing is rolled until `roll()` or
   * `initialRoll()` is called.
   *
   * @param {number} number - Number of dice in the pool
   * @param {number} [sides=6] - Number of sides on each die
   * @param {Function|Function[]} [transformers=[]] - Transformers `(roll, value) => newValue`, applied in order
   * @param {Function} [evaluator] - `(final, roll) => result`. Defaults to returning the final value.
   */
  constructor(number, sides = 6, transformers = [], evaluator = (final) => final) {
    this.#number = number;
    this.#sides = sides;
    this.#dieFn = (sides) => Math.rand_int_between(1, sides);
    this.#rolls = [];
    this.transformers = transformers;
    this.#evaluator = evaluator;
    this.#flags = {};
    this.#edits = [];
    this.#extraDice = [];
    this.#extraKeyed = new Map();
    this.#extraIdx = 0;
    this.#transforming = false;
  }

  /**
   * Number of dice in the pool.
   * @type {number}
   */
  get number() {
    return this.#number;
  }

  /**
   * Number of sides on each die.
   * @type {number}
   */
  get sides() {
    return this.#sides;
  }

  /**
   * The function used to roll one die, `(sides) => number`. Replace it to use a
   * seeded or scripted random number generator.
   * @type {Function}
   */
  get dieFn() {
    return this.#dieFn;
  }

  set dieFn(fn) {
    this.#dieFn = fn;
  }

  /**
   * Every stage of the roll: `rolls[0]` is the raw dice, followed by the output of
   * each transformer in order.
   * @type {Array}
   */
  get rolls() {
    return this.#rolls;
  }

  /**
   * The raw dice (`rolls[0]`). Edit them with `setDie`, `adjustDie` or `rerollDie`.
   * @type {number[]}
   */
  get dice() {
    return this.#rolls[0];
  }

  /**
   * The output of the last stage (what the evaluator receives).
   * @type {*}
   */
  get final() {
    return this.#rolls.at(-1);
  }

  /**
   * The transformers. Assigning a single function wraps it in an array.
   * @type {Function[]}
   */
  get transformers() {
    return this.#transformers;
  }

  set transformers(transformers) {
    this.#transformers = Array.isArray(transformers) ? transformers : [transformers];
  }

  /**
   * The evaluator, `(final, roll) => result`.
   * @type {Function}
   */
  get evaluator() {
    return this.#evaluator;
  }

  set evaluator(evaluator) {
    this.#evaluator = evaluator;
  }

  /**
   * The result of the last `evaluate()`.
   * @type {*}
   */
  get result() {
    return this.#result;
  }

  /**
   * Annotations made by transformers during the last `transform()`, e.g.
   * `flags.critical`. Reset at the start of every transform.
   * @type {Object}
   */
  get flags() {
    return this.#flags;
  }

  /**
   * The log of edits made to the dice since the last `initialRoll()`. Each entry is
   * `{action, index, from, to, reason}`.
   * @type {Object[]}
   */
  get edits() {
    return this.#edits;
  }

  /**
   * Rolls one die with this roll's number of sides.
   *
   * While transformers are running, extra dice are recorded the first time and
   * replayed on later passes, so `recompute()` gives the same extra dice. Pass a
   * `key` to tie a die to a particular use (e.g. `"explode:2:0"`). Without a key,
   * dice are replayed in call order.
   *
   * @param {string} [key] - Optional stable identifier for this extra die
   * @returns {number} A value between 1 and `sides`
   */
  die(key) {
    if(!this.#transforming) {
      return this.#dieFn(this.sides);
    }

    if(key !== undefined) {
      if(!this.#extraKeyed.has(key)) {
        this.#extraKeyed.set(key, this.#dieFn(this.sides));
      }
      return this.#extraKeyed.get(key);
    }

    if(this.#extraIdx >= this.#extraDice.length) {
      this.#extraDice.push(this.#dieFn(this.sides));
    }
    return this.#extraDice[this.#extraIdx++];
  }

  /**
   * Rolls the pool of dice without recording it.
   *
   * @returns {number[]} `number` freshly rolled dice
   */
  rollDice() {
    return Array.from({length: this.number}, () => this.#dieFn(this.sides));
  }

  /**
   * Rolls a new pool into `rolls[0]` and clears earlier stages, flags, edits and
   * recorded extra dice.
   */
  initialRoll() {
    this.#rolls = [this.rollDice()];
    this.#flags = {};
    this.#edits = [];
    this.#extraDice = [];
    this.#extraKeyed = new Map();
    this.#result = undefined;
  }

  #checkIndex(index) {
    if(this.#rolls.length === 0) {
      throw new Error("RezRoll: no dice have been rolled yet");
    }
    if(!Number.isInteger(index) || index < 0 || index >= this.dice.length) {
      throw new Error(`RezRoll: no die at index ${index}`);
    }
  }

  #recordEdit(action, index, to, reason) {
    const from = this.dice[index];
    this.dice[index] = to;
    this.#edits.push({action, index, from, to, reason});
  }

  /**
   * Sets a raw die to a value. Call `recompute()` afterwards to update the result.
   *
   * @param {number} index - Index into `dice`
   * @param {number} value - The new value
   * @param {string} [reason] - Why the die was changed (kept in `edits`)
   */
  setDie(index, value, reason) {
    this.#checkIndex(index);
    this.#recordEdit("set", index, value, reason);
  }

  /**
   * Adds `delta` to a raw die, clamped to between 1 and `sides`. Call `recompute()`
   * afterwards to update the result.
   *
   * @param {number} index - Index into `dice`
   * @param {number} delta - Amount to add (may be negative)
   * @param {string} [reason] - Why the die was changed (kept in `edits`)
   */
  adjustDie(index, delta, reason) {
    this.#checkIndex(index);
    const value = Math.min(this.sides, Math.max(1, this.dice[index] + delta));
    this.#recordEdit("adjust", index, value, reason);
  }

  /**
   * Re-rolls one raw die. Call `recompute()` afterwards to update the result.
   *
   * @param {number} index - Index into `dice`
   * @param {string} [reason] - Why the die was re-rolled (kept in `edits`)
   */
  rerollDie(index, reason) {
    this.#checkIndex(index);
    this.#recordEdit("reroll", index, this.#dieFn(this.sides), reason);
  }

  /**
   * Runs the transformers over `dice`, replacing any earlier stages and resetting
   * `flags`.
   *
   * @throws {Error} If no dice have been rolled yet
   */
  transform() {
    if(this.#rolls.length === 0) {
      throw new Error("RezRoll: call initialRoll() or roll() before transform()");
    }

    this.#rolls.length = 1;
    this.#flags = {};
    this.#extraIdx = 0;
    this.#transforming = true;
    try {
      this.#transformers.reduce((value, transformer) => {
        const next = transformer(this, value);
        this.#rolls.push(next);
        return next;
      }, this.#rolls[0].slice());
    } finally {
      this.#transforming = false;
    }
  }

  /**
   * Passes the final stage to the evaluator and stores the result.
   *
   * @returns {*} The result
   */
  evaluate() {
    this.#result = this.#evaluator(this.final, this);
    return this.#result;
  }

  /**
   * Rolls new dice, transforms them and evaluates them.
   *
   * @returns {*} The result
   */
  roll() {
    this.initialRoll();
    return this.recompute();
  }

  /**
   * Re-runs the transformers and evaluator over the current dice, e.g. after an edit.
   *
   * @returns {*} The result
   */
  recompute() {
    this.transform();
    return this.evaluate();
  }

  //---------------------------------------------------------------------------
  // Transformers
  //---------------------------------------------------------------------------

  /**
   * Transformer: keeps the `n` highest dice, in ascending order.
   *
   * @param {number} n - Number of dice to keep
   * @returns {Function} Transformer
   */
  static keepHighest(n) {
    return (roll, dice) => dice.toSorted((a, b) => a - b).slice(-n);
  }

  /**
   * Transformer: keeps the `n` lowest dice, in ascending order.
   *
   * @param {number} n - Number of dice to keep
   * @returns {Function} Transformer
   */
  static keepLowest(n) {
    return (roll, dice) => dice.toSorted((a, b) => a - b).slice(0, n);
  }

  /**
   * Transformer: exploding dice. Each die showing `on` or more rolls an extra die
   * and adds it (plus `extraOffset`) to its total. With `chain`, extra dice that
   * also show `on` explode again.
   *
   * Extra dice are replayed on `recompute()`, so editing one die doesn't change
   * the explosions of the others.
   *
   * @param {Object} [options]
   * @param {number} [options.on] - Value that triggers an explosion (default: `sides`)
   * @param {boolean} [options.chain=true] - Whether extra dice can explode too
   * @param {number} [options.extraOffset=0] - Added to each extra die (`-1` gives Conquest of Elysium 5 style)
   * @returns {Function} Transformer
   */
  static explode({on, chain = true, extraOffset = 0} = {}) {
    return (roll, dice) => dice.map((value, index) => {
      const trigger = on ?? roll.sides;
      let total = value;
      let last = value;
      let n = 0;
      while(last >= trigger) {
        last = roll.die(`explode:${index}:${n++}`);
        total += last + extraOffset;
        if(!chain) break;
      }
      return total;
    });
  }

  /**
   * Transformer: sets `flags.critical` if every die at this stage shows the maximum
   * (`>= sides`, so exploded dice count) or every die shows 1. The dice pass
   * through unchanged. Put it after the keep step to check only the kept dice.
   *
   * @param {Object} [options]
   * @param {*} [options.max="success"] - Flag value when every die is at maximum (`null` to disable)
   * @param {*} [options.min="failure"] - Flag value when every die is 1 (`null` to disable)
   * @returns {Function} Transformer
   */
  static critOnAll({max = "success", min = "failure"} = {}) {
    return (roll, dice) => {
      if(dice.length > 0) {
        if(max !== null && dice.every((d) => d >= roll.sides)) {
          roll.flags.critical = max;
        } else if(min !== null && dice.every((d) => d === 1)) {
          roll.flags.critical = min;
        }
      }
      return dice;
    };
  }

  /**
   * Transformer: sums the dice and adds `mod`.
   *
   * @param {number} [mod=0] - Modifier added to the sum
   * @returns {Function} Transformer producing a number
   */
  static sum(mod = 0) {
    return (roll, dice) => dice.reduce((a, b) => a + b, mod);
  }

  /**
   * Transformer: the highest die.
   *
   * @returns {Function} Transformer producing a number
   */
  static highest() {
    return (roll, dice) => Math.max(...dice);
  }

  /**
   * Transformer: counts the dice matching a predicate.
   *
   * @param {Function} pred - `(die) => boolean`
   * @returns {Function} Transformer producing a number
   */
  static countIf(pred) {
    return (roll, dice) => dice.filter(pred).length;
  }

  /**
   * Transformer: counts successes and failures in a dice pool.
   *
   * @param {Object} [options]
   * @param {number} [options.successOn] - A die `>=` this is a success (default: `sides`)
   * @param {number} [options.failOn] - A die `<=` this is a failure (default: none)
   * @param {number} [options.mod=0] - Added to `net`
   * @returns {Function} Transformer producing `{successes, failures, net}`
   */
  static countSuccesses({successOn, failOn, mod = 0} = {}) {
    return (roll, dice) => {
      const threshold = successOn ?? roll.sides;
      const successes = dice.filter((d) => d >= threshold).length;
      const failures = failOn === undefined ? 0 : dice.filter((d) => d <= failOn).length;
      return {successes, failures, net: successes - failures + mod};
    };
  }

  //---------------------------------------------------------------------------
  // Evaluators
  //---------------------------------------------------------------------------

  /**
   * Evaluator: true if the final value is greater than `target`.
   *
   * @param {number} target
   * @returns {Function} Evaluator
   */
  static beats(target) {
    return (final) => final > target;
  }

  /**
   * Evaluator: true if the final value is at least `target`.
   *
   * @param {number} target
   * @returns {Function} Evaluator
   */
  static meets(target) {
    return (final) => final >= target;
  }

  /**
   * Evaluator: returns the name of the first rule whose test passes, or `null`.
   *
   * @param {Array<Array>} rules - `[[name, (final, roll) => boolean], ...]`
   * @returns {Function} Evaluator
   *
   * @example
   * RezRoll.outcome([
   *   ["crit", (f, r) => r.flags.critical === "success"],
   *   ["success", (f) => f > 8],
   *   ["failure", () => true]
   * ])
   */
  static outcome(rules) {
    return (final, roll) => {
      const match = rules.find(([, test]) => test(final, roll));
      return match ? match[0] : null;
    };
  }

  //---------------------------------------------------------------------------
  // Presets
  //---------------------------------------------------------------------------

  /**
   * Preset: 2d6 + bonus vs target. With advantage, roll 3d6 and keep the best 2.
   * With disadvantage, keep the worst 2. Kept double 6 is `"crit_success"` and
   * kept double 1 is `"crit_failure"`. Otherwise the result is `"success"` or
   * `"failure"`.
   *
   * @param {Object} [options]
   * @param {number} [options.bonus=0] - Added to the sum
   * @param {number} [options.target=8] - Number to compare against
   * @param {string} [options.mode="normal"] - `"normal"`, `"advantage"` or `"disadvantage"`
   * @param {string} [options.op=">"] - `">"` (must beat target) or `">="` (must meet it)
   * @returns {RezRoll}
   */
  static twoD6({bonus = 0, target = 8, mode = "normal", op = ">"} = {}) {
    const transformers = [];
    let number = 2;
    if(mode === "advantage") {
      number = 3;
      transformers.push(RezRoll.keepHighest(2));
    } else if(mode === "disadvantage") {
      number = 3;
      transformers.push(RezRoll.keepLowest(2));
    } else if(mode !== "normal") {
      throw new Error(`RezRoll.twoD6: unknown mode "${mode}"`);
    }
    transformers.push(RezRoll.critOnAll(), RezRoll.sum(bonus));

    const passes = op === ">=" ? (f) => f >= target : (f) => f > target;

    return new RezRoll(number, 6, transformers, RezRoll.outcome([
      ["crit_success", (f, r) => r.flags.critical === "success"],
      ["crit_failure", (f, r) => r.flags.critical === "failure"],
      ["success", passes],
      ["failure", () => true]
    ]));
  }

  /**
   * Preset: d20 check in the style of D&D. Roll a d20, add `bonus` and compare
   * with `dc`; meeting the DC succeeds. With advantage, roll 2d20 and keep the
   * higher; with disadvantage, keep the lower. If `crits` is on, a kept natural
   * 20 is `"crit_success"` and a kept natural 1 is `"crit_failure"`, whatever
   * the total (as for attack rolls). Otherwise the result is `"success"` or
   * `"failure"`.
   *
   * @param {Object} [options]
   * @param {number} [options.bonus=0] - Modifier added to the die
   * @param {number} [options.dc=10] - Difficulty class; the total must be at least this
   * @param {string} [options.mode="normal"] - `"normal"`, `"advantage"` or `"disadvantage"`
   * @param {boolean} [options.crits=true] - Whether natural 20s and 1s are criticals
   * @returns {RezRoll}
   *
   * @example
   * const attack = RezRoll.d20({bonus: 5, dc: target.ac, mode: "advantage"});
   * attack.roll();   // => e.g. "success"
   * attack.dice;     // => [7, 14] (both d20s)
   * attack.rolls[1]; // => [14] (the kept die)
   * attack.final;    // => 19 (14 + 5)
   */
  static d20({bonus = 0, dc = 10, mode = "normal", crits = true} = {}) {
    const transformers = [];
    let number = 1;
    if(mode === "advantage") {
      number = 2;
      transformers.push(RezRoll.keepHighest(1));
    } else if(mode === "disadvantage") {
      number = 2;
      transformers.push(RezRoll.keepLowest(1));
    } else if(mode !== "normal") {
      throw new Error(`RezRoll.d20: unknown mode "${mode}"`);
    }
    if(crits) {
      transformers.push(RezRoll.critOnAll());
    }
    transformers.push(RezRoll.sum(bonus));

    return new RezRoll(number, 20, transformers, RezRoll.outcome([
      ["crit_success", (f, r) => r.flags.critical === "success"],
      ["crit_failure", (f, r) => r.flags.critical === "failure"],
      ["success", (f) => f >= dc],
      ["failure", () => true]
    ]));
  }

  /**
   * Preset: Blades in the Dark action roll. Roll `pool` d6 and read the highest:
   * two or more 6s is `"critical"`, 6 is `"success"`, 4–5 is `"partial"` and
   * 1–3 is `"failure"`. With zero dice (or fewer), roll 2d6 and take the lowest,
   * which can't be a critical.
   *
   * @param {number} pool - Number of dice
   * @returns {RezRoll}
   */
  static blades(pool) {
    const zero = pool <= 0;
    const transformers = zero
      ? [RezRoll.keepLowest(1), RezRoll.highest()]
      : [RezRoll.highest()];

    return new RezRoll(zero ? 2 : pool, 6, transformers, RezRoll.outcome([
      ["critical", (f, r) => !zero && r.dice.filter((d) => d === 6).length >= 2],
      ["success", (f) => f === 6],
      ["partial", (f) => f >= 4],
      ["failure", () => true]
    ]));
  }
}

window.Rez.RezRoll = RezRoll;
