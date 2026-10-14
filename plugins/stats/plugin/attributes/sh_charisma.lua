--- Charisma stat: the presence and force of personality of a character, from -3 (terrible)
-- to 5 (legendary); a new character picks at most 3 (superb). The level is the modifier it
-- adds to a roll. Every level lowers the prices vendors ask of the character by the
-- `stats_charisma_prices` config. Levels below zero raise them.
-- The icon is a FontAwesome one, as the content of the schema has no image for this stat.

ATTRIBUTE.name = 'attribute.charisma.title'
ATTRIBUTE.description = 'attribute.charisma.description'
ATTRIBUTE.icon = 'fa-comments'
ATTRIBUTE.min = -3
ATTRIBUTE.max = 5
ATTRIBUTE.creation_max = 3
ATTRIBUTE.default = 0
ATTRIBUTE.levels = {
  legendary = 'attribute.charisma.legendary',
  heroic = 'attribute.charisma.heroic',
  superb = 'attribute.charisma.superb',
  great = 'attribute.charisma.great',
  good = 'attribute.charisma.good',
  fair = 'attribute.charisma.fair',
  mediocre = 'attribute.charisma.mediocre',
  poor = 'attribute.charisma.poor',
  terrible = 'attribute.charisma.terrible'
}

ATTRIBUTE.effects = {
  Stats:percent_effect('ui.effect.vendor_prices', 'stats_charisma_prices', true, function()
    return Vendors != nil
  end)
}
