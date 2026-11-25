--- Perception stat: the awareness of a character, from -3 (terrible) to 5 (legendary);
-- a new character picks at most 3 (superb). The level is the modifier it adds to a roll.
-- Every level extends the range at which the character hears in-character speech by the
-- `stats_perception_hearing` config, in meters. Levels below zero shorten it.

ATTRIBUTE.name = 'attribute.perception.title'
ATTRIBUTE.description = 'attribute.perception.description'
ATTRIBUTE.icon = 'flux/icons/eye-target.png'
ATTRIBUTE.min = -3
ATTRIBUTE.max = 5
ATTRIBUTE.creation_max = 3
ATTRIBUTE.default = 0
ATTRIBUTE.order = 4

ATTRIBUTE.effects = {
  Stats:distance_effect('ui.effect.hearing_radius', 'stats_perception_hearing')
}
