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

class RezDieRoll {
  #die;
  #count;
  #modifier;
  #rounds;
  #exploding;
  #advantage;
  #disadvantage;

  constructor(count, sides = 6, modifier = 0, rounds = 1) {
    this.#die = new RezDie(sides);
    this.#count = count;
    this.#modifier = modifier;
    this.#rounds = rounds;
    this.#exploding = false;
    this.#advantage = false;
    this.#disadvantage = false;
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

  set exploding(exploding) {
    this.#exploding = exploding;
    if(exploding) {
      this.#advantage = false;
      this.#disadvantage = false;
    }
    return this;
  }

  set advantage(advantage) {
    this.#advantage = advantage;
    if(advantage) {
      this.#exploding = false;
      this.#disadvantage = false;
    }
    return this;
  }

  set disadvantage(disadvantage) {
    this.#disadvantage = disadvantage;
    if(disadvantage) {
      this.#exploding = false;
      this.#advantage = false;
    }
    return this;
  }

  copy() {
    const die = new RezDieRoll(this.count, this.sides, this.modifier, this.rounds);
    die.#exploding = this.#exploding;
    die.#advantage = this.#advantage;
    die.#disadvantage = this.#disadvantage;
    return die;
  }

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

  rollWithAdvantage() {
    return [this.rollDice(), this.rollDice()].max();
  }

  rollWithDisadvange() {
    return [this.rollDice(), this.rollDice()].min();
  }

  rollRound() {
    if(this.#advantage) {
      return this.rollWithAdvantage();
    } else if(this.#disadvantage) {
      return this.rollWithDisadvange();
    } else {
      return this.rollDice();
    }
  }

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

window.Rez.D4 = Rez.makeDie("d4");
window.Rez.rollD4 = () => window.Rez.D4.roll();
window.Rez.D6 = Rez.makeDie("d6");
window.Rez.rollD6 = () => window.Rez.D6.roll();
window.Rez.D8 = Rez.makeDie("d8");
window.Rez.rollD8 = () => window.Rez.D8.roll();
window.Rez.D10 = Rez.makeDie("d10");
window.Rez.rollD10 = () => window.Rez.D10.roll();
window.Rez.D12 = Rez.makeDie("d12");
window.Rez.rollD12 = () => window.Rez.D12.roll();
window.Rez.D20 = Rez.makeDie("d20");
window.Rez.rollD20 = () => window.Rez.D20.roll();
window.Rez.D100 = Rez.makeDie("d100");
window.Rez.rollD100 = () => window.Rez.D100.roll();
