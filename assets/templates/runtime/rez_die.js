//-----------------------------------------------------------------------------
// Dice
//-----------------------------------------------------------------------------

function RezDie(sides = 6) {
  this.sides = sides;
}

RezDie.prototype = {
  constructor: RezDie,

  roll() {
    return Math.rand_int_between(1, this.sides);
  }
};

window.Rez.RezDie = RezDie;

function RezDieRoll(count, sides, modifier, rounds = 1) {
  this.die = new RezDie(sides);
  this.count = count;
  this.modifier = modifier;
  this.rounds = rounds;
}

RezDieRoll.prototype = {
  constructor: RezDieRoll,

  rollRound() {
    let sum = this.modifier;
    for (let i = 0; i < this.count; i++) {
      sum += this.die.roll();
    }
    return sum;
  },

  roll() {
    if (this.rounds == 1) {
      return this.rollRound();
    } else {
      const sum = Number.range(1, this.rounds)
        .map(() => this.rollRound())
        .reduce((sum, round) => sum + round, 0);
      return sum.cl_avg(this.rounds);
    }
  },

  description() {
    return `${this.desc_count()}d${this.die.sides}${this.desc_mod()}`;
  },

  desc_count() {
    if(this.count > 0) {
      return `${this.count}`;
    } else {
      return "";
    }
  },

  desc_mod() {
    if(this.modifier < 0) {
      return `${this.modifier}`;
    } else if(this.modifier > 0) {
      return `+${this.modifier}`;
    } else {
      return "";
    }
  }
};

window.Rez.RezDieRoll = RezDieRoll;
