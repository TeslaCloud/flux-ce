--- Intelligence stat: the strength of mind of a character, from -3 (terrible) to 5 (legendary);
-- a new character picks at most 3 (superb). The level is the modifier it adds to a roll.
-- It is the key stat of medicine, crafting, technology and lore, and changes nothing else in
-- play.

ATTRIBUTE.name = 'attribute.intelligence.title'
ATTRIBUTE.description = 'attribute.intelligence.description'
ATTRIBUTE.icon = 'flux/icons/bookmarklet.png'
ATTRIBUTE.type = ATTRIBUTE_STAT
ATTRIBUTE.min = -3
ATTRIBUTE.max = 5
ATTRIBUTE.creation_max = 3
ATTRIBUTE.default = 0
ATTRIBUTE.levels = {
  legendary = 'attribute.intelligence.legendary',
  heroic = 'attribute.intelligence.heroic',
  superb = 'attribute.intelligence.superb',
  great = 'attribute.intelligence.great',
  good = 'attribute.intelligence.good',
  fair = 'attribute.intelligence.fair',
  mediocre = 'attribute.intelligence.mediocre',
  poor = 'attribute.intelligence.poor',
  terrible = 'attribute.intelligence.terrible'
}
