//-----------------------------------------------------------------------------
// Dice
//-----------------------------------------------------------------------------

/**
 * @class RezDie
 * @description Represents a single die with a configurable number of sides.
 *
 * Provides basic rolling functionality including standard rolls and "open" (exploding)
 * rolls where rolling the maximum value causes a re-roll that adds to the total.
 *
 * @example
 * const d6 = new RezDie(6);
 * const result = d6.roll(); // Returns 1-6
 *
 * @example
 * // Open roll - if you roll max, roll again and add
 * const d6 = new RezDie(6);
 * const result = d6.open_roll(); // Could return 7+ if 6 was rolled
 */
class RezDie {
  /** @type {number} */
  #sides;

  /**
   * Creates a new die.
   *
   * @param {number} [sides=6] - The number of sides on the die
   */
  constructor(sides = 6) {
    this.#sides = sides;
  }

  /**
   * The number of sides on this die.
   * @type {number}
   */
  get sides() {
    return this.#sides;
  }

  /**
   * Rolls the die once.
   *
   * @returns {number} A random value between 1 and the number of sides
   */
  roll() {
    return Math.rand_int_between(1, this.sides);
  }

  /**
   * Performs an "open" or "exploding" roll.
   *
   * If the maximum value is rolled, the die is rolled again and the results
   * are summed. This continues until a non-maximum value is rolled.
   *
   * @returns {number} The total of all rolls
   *
   * @example
   * // On a d6, rolling 6, 6, 3 would return 15
   */
  open_roll() {
    let roll, total = 0;

    do {
      roll = this.roll();
      total += roll;
    } while(roll == this.sides);

    return total;
  }
}

window.Rez.RezDie = RezDie;

/**
 * @class RezDieRoll
 * @description Represents a dice roll configuration with multiple dice, modifiers, and special rules.
 *
 * Supports:
 * - Multiple dice of the same type (e.g., 3d6)
 * - Numeric modifiers (e.g., 2d6+3)
 * - Exploding dice (re-roll and add on max)
 * - Advantage (roll twice, take higher)
 * - Disadvantage (roll twice, take lower)
 * - Multiple rounds with averaging
 *
 * @example
 * // Roll 2d6+3
 * const roll = new RezDieRoll(2, 6, 3);
 * const result = roll.roll();
 *
 * @example
 * // Roll with advantage
 * const roll = new RezDieRoll(1, 20, 0);
 * roll.advantage = true;
 * const result = roll.roll(); // Rolls twice, takes higher
 */
class RezDieRoll {
  /** @type {RezDie} */
  #die;
  /** @type {number} */
  #count;
  /** @type {number} */
  #modifier;
  /** @type {number} */
  #rounds;
  /** @type {boolean} */
  #exploding;
  /** @type {boolean} */
  #advantage;
  /** @type {boolean} */
  #disadvantage;

  /**
   * Creates a new dice roll configuration.
   *
   * @param {number} count - Number of dice to roll
   * @param {number} [sides=6] - Number of sides per die
   * @param {number} [modifier=0] - Flat modifier to add to the result
   * @param {number} [rounds=1] - Number of rounds to roll (results are averaged)
   */
  constructor(count, sides = 6, modifier = 0, rounds = 1) {
    this.#die = new RezDie(sides);
    this.#count = count;
    this.#modifier = modifier;
    this.#rounds = rounds;
    this.#exploding = false;
    this.#advantage = false;
    this.#disadvantage = false;
  }

  /**
   * Number of dice to roll.
   * @type {number}
   */
  get count() {
    return this.#count;
  }

  /**
   * The underlying die object.
   * @type {RezDie}
   */
  get die() {
    return this.#die;
  }

  /**
   * Number of sides on each die.
   * @type {number}
   */
  get sides() {
    return this.#die.sides;
  }

  /**
   * Flat modifier added to the roll result.
   * @type {number}
   */
  get modifier() {
    return this.#modifier;
  }

  /**
   * Number of rounds to roll (results are averaged).
   * @type {number}
   */
  get rounds() {
    return this.#rounds;
  }

  /**
   * Enables or disables exploding dice.
   *
   * When enabled, rolling the maximum value causes a re-roll that adds to the total.
   * Mutually exclusive with advantage and disadvantage.
   *
   * @type {boolean}
   */
  set exploding(exploding) {
    this.#exploding = exploding;
    if(exploding) {
      this.#advantage = false;
      this.#disadvantage = false;
    }
    return this;
  }

  /**
   * Enables or disables advantage.
   *
   * When enabled, rolls twice and takes the higher result.
   * Mutually exclusive with exploding and disadvantage.
   *
   * @type {boolean}
   */
  set advantage(advantage) {
    this.#advantage = advantage;
    if(advantage) {
      this.#exploding = false;
      this.#disadvantage = false;
    }
    return this;
  }

  /**
   * Enables or disables disadvantage.
   *
   * When enabled, rolls twice and takes the lower result.
   * Mutually exclusive with exploding and advantage.
   *
   * @type {boolean}
   */
  set disadvantage(disadvantage) {
    this.#disadvantage = disadvantage;
    if(disadvantage) {
      this.#exploding = false;
      this.#advantage = false;
    }
    return this;
  }

  /**
   * Creates a copy of this dice roll configuration.
   *
   * @returns {RezDieRoll} A new RezDieRoll with the same settings
   */
  copy() {
    const die = new RezDieRoll(this.count, this.sides, this.modifier, this.rounds);
    die.#exploding = this.#exploding;
    die.#advantage = this.#advantage;
    die.#disadvantage = this.#disadvantage;
    return die;
  }

  /**
   * Rolls all dice once and returns the sum plus modifier.
   *
   * If exploding is enabled, uses open rolls for each die.
   *
   * @returns {number} The total of all dice plus modifier
   */
  rollDice() {
    let sum = this.modifier;
    for (let i = 0; i < this.count; i++) {
      if(this.#exploding) {
        sum += this.die.open_roll();
      } else {
        sum += this.die.roll();
      }

    }
    return sum;
  }

  /**
   * Rolls twice and returns the higher result.
   *
   * @returns {number} The higher of two roll results
   */
  rollWithAdvantage() {
    return [this.rollDice(), this.rollDice()].max();
  }

  /**
   * Rolls twice and returns the lower result.
   *
   * @returns {number} The lower of two roll results
   */
  rollWithDisadvange() {
    return [this.rollDice(), this.rollDice()].min();
  }

  /**
   * Performs a single round of rolling, applying advantage/disadvantage if set.
   *
   * @returns {number} The result of this round
   */
  rollRound() {
    if(this.#advantage) {
      return this.rollWithAdvantage();
    } else if(this.#disadvantage) {
      return this.rollWithDisadvange();
    } else {
      return this.rollDice();
    }
  }

  /**
   * Performs the complete roll.
   *
   * If multiple rounds are configured, rolls each round and returns
   * the ceiling average of all rounds.
   *
   * @returns {number} The final roll result
   */
  roll() {
    if(this.rounds == 1) {
      return this.rollRound();
    } else {
      const sum = Math.range(1, this.rounds)
        .map(() => this.rollRound())
        .reduce((sum, round) => sum + round, 0);
      return sum.cl_avg(this.rounds);
    }
  }

  /**
   * Returns a string description of this dice roll (e.g., "2d6+3").
   *
   * @returns {string} The dice notation string
   */
  description() {
    return `${this.desc_count()}d${this.die.sides}${this.desc_mod()}`;
  }

  /**
   * Returns the count portion of the dice notation.
   *
   * @returns {string} The count as a string, or empty if count is 0
   */
  desc_count() {
    if(this.count > 0) {
      return `${this.count}`;
    } else {
      return "";
    }
  }

  /**
   * Returns the modifier portion of the dice notation.
   *
   * @returns {string} The modifier with sign (e.g., "+3" or "-2"), or empty if 0
   */
  desc_mod() {
    if(this.modifier < 0) {
      return `${this.modifier}`;
    } else if(this.modifier > 0) {
      return `+${this.modifier}`;
    } else {
      return "";
    }
  }
}

window.Rez.RezDieRoll = RezDieRoll;

/**
 * @function makeDie
 * @memberof Rez
 * @description Parses a dice notation string and creates a RezDieRoll.
 *
 * Supports standard dice notation with optional modifiers and special flags:
 * - Basic: "d6", "2d6", "3d8"
 * - With modifier: "2d6+3", "d20-1"
 * - With advantage: "d20a"
 * - With disadvantage: "d20d"
 * - Exploding: "2d6!"
 *
 * @param {string} diceStr - The dice notation string to parse
 * @returns {RezDieRoll} A configured RezDieRoll object
 * @throws {Error} If the dice format is invalid
 *
 * @example
 * const roll = Rez.makeDie("2d6+3");
 * const result = roll.roll();
 *
 * @example
 * const roll = Rez.makeDie("d20a"); // d20 with advantage
 */
window.Rez.makeDie = function(diceStr) {
  const regex = /^(\d+)?d(\d+)([\+\-]\d+)?([!ad])?$/i;
  const match = diceStr.match(regex);

  if (!match) {
    throw new Error('Invalid dice format');
  }

  const [_, count = '1', sides, modifier = '0', special] = match;
  const numDice = parseInt(count);
  const numSides = parseInt(sides);
  const mod = parseInt(modifier);

  const die = new RezDieRoll(numDice, numSides, mod);

  if(special === "a") {
    die.advantage = true;
  } else if(special === "d") {
    die.disadvantage = true;
  } else if(special === "!") {
    die.exploding = true
  };

  return die;
}

/** Pre-configured d4 */
window.Rez.D4 = Rez.makeDie("d4");
/** Rolls a d4 @returns {number} */
window.Rez.rollD4 = () => window.Rez.D4.roll();
/** Pre-configured d6 */
window.Rez.D6 = Rez.makeDie("d6");
/** Rolls a d6 @returns {number} */
window.Rez.rollD6 = () => window.Rez.D6.roll();
/** Pre-configured d8 */
window.Rez.D8 = Rez.makeDie("d8");
/** Rolls a d8 @returns {number} */
window.Rez.rollD8 = () => window.Rez.D8.roll();
/** Pre-configured d10 */
window.Rez.D10 = Rez.makeDie("d10");
/** Rolls a d10 @returns {number} */
window.Rez.rollD10 = () => window.Rez.D10.roll();
/** Pre-configured d12 */
window.Rez.D12 = Rez.makeDie("d12");
/** Rolls a d12 @returns {number} */
window.Rez.rollD12 = () => window.Rez.D12.roll();
/** Pre-configured d20 */
window.Rez.D20 = Rez.makeDie("d20");
/** Rolls a d20 @returns {number} */
window.Rez.rollD20 = () => window.Rez.D20.roll();
/** Pre-configured d100 */
window.Rez.D100 = Rez.makeDie("d100");
/** Rolls a d100 @returns {number} */
window.Rez.rollD100 = () => window.Rez.D100.roll();
