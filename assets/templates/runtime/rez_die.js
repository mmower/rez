//-----------------------------------------------------------------------------
// Dice
//-----------------------------------------------------------------------------

class RezDie {
  #sides;

  constructor(sides = 6) {
    this.#sides = sides;
  }

  get sides() {
    return this.#sides;
  }

  roll() {
    return Math.rand_int_between(1, this.sides);
  }
}

window.Rez.RezDie = RezDie;

class RezDieRoll {
  #die;
  #count;
  #modifier;
  #rounds;

  constructor(count, sides = 6, modifier = 0, rounds = 1) {
    this.#die = new RezDie(sides);
    this.#count = count;
    this.#modifier = modifier;
    this.#rounds = rounds;
  }

  get count() {
    return this.#count;
  }

  get die() {
    return this.#die;
  }

  get sides() {
    return this.#die.sides;
  }

  get modifier() {
    return this.#modifier;
  }

  get rounds() {
    return this.#rounds;
  }

  rollRound() {
    let sum = this.modifier;
    for (let i = 0; i < this.count; i++) {
      sum += this.die.roll();
    }
    return sum;
  }

  roll() {
    if(this.rounds == 1) {
      return this.rollRound();
    } else {
      const sum = Number.range(1, this.rounds)
        .map(() => this.rollRound())
        .reduce((sum, round) => sum + round, 0);
      return sum.cl_avg(this.rounds);
    }
  }

  description() {
    return `${this.desc_count()}d${this.die.sides}${this.desc_mod()}`;
  }

  desc_count() {
    if(this.count > 0) {
      return `${this.count}`;
    } else {
      return "";
    }
  }

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
