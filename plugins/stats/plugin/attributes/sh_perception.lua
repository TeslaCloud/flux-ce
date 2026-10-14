--- Perception stat: the awareness of a character, from -3 (terrible) to 5 (legendary);
-- a new character picks at most 3 (superb). The level is the modifier it adds to a roll.
-- Every level extends the range at which the character hears in-character speech by the
-- `stats_perception_hearing` config, in meters. Levels below zero shorten it.

ATTRIBUTE.name = 'attribute.perception.title'
ATTRIBUTE.description = 'attribute.perception.description'
ATTRIBUTE.icon = 'flux/icons/eye-target.png'
ATTRIBUTE.type = ATTRIBUTE_STAT
ATTRIBUTE.min = -3
ATTRIBUTE.max = 5
ATTRIBUTE.creation_max = 3
ATTRIBUTE.default = 0
ATTRIBUTE.levels = {
  legendary = 'attribute.perception.legendary',
  heroic = 'attribute.perception.heroic',
  superb = 'attribute.perception.superb',
  great = 'attribute.perception.great',
  good = 'attribute.perception.good',
  fair = 'attribute.perception.fair',
  mediocre = 'attribute.perception.mediocre',
  poor = 'attribute.perception.poor',
  terrible = 'attribute.perception.terrible'
}

ATTRIBUTE.effects = {
  Stats:distance_effect('ui.effect.hearing_radius', 'stats_perception_hearing')
}
