//-----------------------------------------------------------------------------
// Dice
//-----------------------------------------------------------------------------

function RezDie(sides = 6) {
  this.sides = sides;
}

RezDie.prototype = {
  constructor: RezDie,

  roll() {
    return Number.rand_between(1, this.sides);
  }
};

window.RezDie = RezDie;

window.RezDie.D4 = new RezDie(4);
window.RezDie.D6 = new RezDie(6);
window.RezDie.D8 = new RezDie(8);
window.RezDie.D10 = new RezDie(10);
window.RezDie.D12 = new RezDie(12);
window.RezDie.D20 = new RezDie(20);
window.RezDie.D100 = new RezDie(100);

function RezDieRoll(sides = 6, count = 1, modifier = 0, rounds = 1) {
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

window.RezDieRoll = RezDieRoll;
