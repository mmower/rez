//-----------------------------------------------------------------------------
// Random
//-----------------------------------------------------------------------------

/**
 * @class RezRandom
 * @category Utilities
 * @description A seedable pseudo-random number generator (sfc32) whose whole state is
 * four 32-bit integers.
 *
 * Rez replaces `Math.random()` with the game's generator, `Rez.rng` (also available as
 * `$game.rng`). Everything that uses `Math.random()` then draws from one stream whose
 * state can be saved and restored: the stdlib helpers (`Math.rand_int`, `Array#fyShuffle`,
 * dice rolls and so on) and your own scripts. This is what lets the game:
 * - give the same sequence of numbers every run, if `@game` sets `rng_seed`
 * - save the generator's state in save files, so a loaded game makes the same rolls it would have made
 * - roll randomness back after a lookahead (see `RezGame#lookahead`)
 *
 * The original browser function is still available as `RezRandom.nativeRandom`.
 *
 * @example
 * const rng = new RezRandom(42);
 * const saved = rng.state;
 * const a = rng.next();
 * rng.state = saved;
 * rng.next() === a; // true
 */
class RezRandom {
  #a;
  #b;
  #c;
  #d;

  /**
   * @function constructor
   * @memberof RezRandom
   * @param {number|string} [seed] - seed for the generator; if omitted a seed is chosen at random
   */
  constructor(seed) {
    this.seed(typeof(seed) === "undefined" ? RezRandom.randomSeed() : seed);
  }

  /**
   * @function seed
   * @memberof RezRandom#
   * @param {number|string} seed - a number, or a string which is hashed to a number
   * @description Resets the generator so that it produces the sequence for this seed.
   */
  seed(seed) {
    let s = RezRandom.seedToInt(seed);

    // splitmix32 spreads a single 32-bit seed across the four words of state
    const splitmix = () => {
      s = (s + 0x9e3779b9) | 0;
      let z = s;
      z = Math.imul(z ^ (z >>> 16), 0x85ebca6b);
      z = Math.imul(z ^ (z >>> 13), 0xc2b2ae35);
      return (z ^ (z >>> 16)) >>> 0;
    };

    this.#a = splitmix();
    this.#b = splitmix();
    this.#c = splitmix();
    this.#d = splitmix();

    // Discard the first outputs, which are less well mixed
    for(let i = 0; i < 12; i++) {
      this.next();
    }
  }

  /**
   * @function next
   * @memberof RezRandom#
   * @returns {number} a number in the range [0, 1), like `Math.random()`
   */
  next() {
    const t = (((this.#a + this.#b) | 0) + this.#d) | 0;
    this.#d = (this.#d + 1) | 0;
    this.#a = this.#b ^ (this.#b >>> 9);
    this.#b = (this.#c + (this.#c << 3)) | 0;
    this.#c = (this.#c << 21) | (this.#c >>> 11);
    this.#c = (this.#c + t) | 0;
    return (t >>> 0) / 4294967296;
  }

  /**
   * @function state
   * @memberof RezRandom#
   * @returns {number[]} a copy of the generator's state, four unsigned 32-bit integers
   * @description Use the getter to save the state and the setter to go back to it. The
   * state is a plain array, so it can be stored in JSON.
   */
  get state() {
    return [this.#a >>> 0, this.#b >>> 0, this.#c >>> 0, this.#d >>> 0];
  }

  set state(state) {
    if(!Array.isArray(state) || state.length !== 4 || !state.every(Number.isInteger)) {
      throw new Error(`RezRandom: invalid state ${JSON.stringify(state)}`);
    }
    [this.#a, this.#b, this.#c, this.#d] = state.map((n) => n | 0);
  }

  /**
   * @function seedToInt
   * @memberof RezRandom
   * @param {number|string} seed
   * @returns {number} a 32-bit integer derived from the seed (strings are hashed with FNV-1a)
   */
  static seedToInt(seed) {
    if(typeof(seed) === "number") {
      return Math.floor(seed) | 0;
    } else if(typeof(seed) === "string") {
      let h = 0x811c9dc5;
      for(let i = 0; i < seed.length; i++) {
        h = Math.imul(h ^ seed.charCodeAt(i), 0x01000193);
      }
      return h | 0;
    } else {
      throw new Error(`RezRandom: seed must be a number or string, got ${typeof(seed)}`);
    }
  }

  /**
   * @function randomSeed
   * @memberof RezRandom
   * @returns {number} an unpredictable 32-bit seed
   */
  static randomSeed() {
    if(typeof(globalThis.crypto?.getRandomValues) === "function") {
      return globalThis.crypto.getRandomValues(new Uint32Array(1))[0] | 0;
    }
    return Math.floor(RezRandom.nativeRandom() * 4294967296) | 0;
  }
}

/**
 * The browser's original `Math.random`, before Rez replaced it with `Rez.rng`.
 * @type {Function}
 */
RezRandom.nativeRandom = Math.random;

window.Rez.RezRandom = RezRandom;
window.Rez.rng = new RezRandom();

// From here on all calls to Math.random() draw from the game's generator, so that its
// state can be saved, restored and rolled back.
Math.random = () => window.Rez.rng.next();
