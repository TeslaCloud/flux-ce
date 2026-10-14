--- Strength stat: the physical power of a character, from -3 (terrible) to 5 (legendary);
-- a new character picks at most 3 (superb). The level is the modifier it adds to a roll.
-- Every level raises the mass of the heaviest object the character can pick up and the
-- force they throw it with by the `stats_strength_lifting` config. Levels below zero lower
-- both.

ATTRIBUTE.name = 'attribute.strength.title'
ATTRIBUTE.description = 'attribute.strength.description'
ATTRIBUTE.icon = 'flux/icons/weight-lifting-up.png'
ATTRIBUTE.min = -3
ATTRIBUTE.max = 5
ATTRIBUTE.creation_max = 3
ATTRIBUTE.default = 0
ATTRIBUTE.levels = {
  legendary = 'attribute.strength.legendary',
  heroic = 'attribute.strength.heroic',
  superb = 'attribute.strength.superb',
  great = 'attribute.strength.great',
  good = 'attribute.strength.good',
  fair = 'attribute.strength.fair',
  mediocre = 'attribute.strength.mediocre',
  poor = 'attribute.strength.poor',
  terrible = 'attribute.strength.terrible'
}

ATTRIBUTE.effects = {
  Stats:percent_effect('ui.effect.carry_mass', 'stats_strength_lifting', false, function()
    return Config.find('pickup_max_mass') != nil
  end),
  Stats:percent_effect('ui.effect.throw_force', 'stats_strength_lifting', false, function()
    return (tonumber(Config.get('pickup_throw_force')) or 0) > 0
  end)
}
