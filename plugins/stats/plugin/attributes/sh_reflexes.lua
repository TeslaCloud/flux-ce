--- Reflexes stat: the dexterity and reaction of a character, from -3 (terrible) to 5 (legendary);
-- a new character picks at most 3 (superb). The level is the modifier it adds to a roll.
-- Every level lowers the fall damage the character takes by the `stats_reflexes_fall`
-- config. Levels below zero raise it.

ATTRIBUTE.name = 'attribute.reflexes.title'
ATTRIBUTE.description = 'attribute.reflexes.description'
ATTRIBUTE.icon = 'flux/icons/body-balance.png'
ATTRIBUTE.type = ATTRIBUTE_STAT
ATTRIBUTE.min = -3
ATTRIBUTE.max = 5
ATTRIBUTE.creation_max = 3
ATTRIBUTE.default = 0
ATTRIBUTE.levels = {
  legendary = 'attribute.reflexes.legendary',
  heroic = 'attribute.reflexes.heroic',
  superb = 'attribute.reflexes.superb',
  great = 'attribute.reflexes.great',
  good = 'attribute.reflexes.good',
  fair = 'attribute.reflexes.fair',
  mediocre = 'attribute.reflexes.mediocre',
  poor = 'attribute.reflexes.poor',
  terrible = 'attribute.reflexes.terrible'
}

ATTRIBUTE.effects = {
  Stats:percent_effect('ui.effect.fall_damage', 'stats_reflexes_fall', true, function()
    return Damage != nil
  end)
}
