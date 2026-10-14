--- Lore skill: knowledge of history, science and culture. Its key stat is intelligence, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under intelligence on the
-- character sheet.

ATTRIBUTE.name = 'attribute.lore.title'
ATTRIBUTE.description = 'attribute.lore.description'
ATTRIBUTE.icon = 'fa-book-open'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'intelligence'
ATTRIBUTE.category = 'attribute.intelligence.title'
ATTRIBUTE.min = 0
ATTRIBUTE.max = 4
ATTRIBUTE.default = 0
ATTRIBUTE.level_order = { 'untrained', 'trained', 'expert', 'master', 'legendary' }
ATTRIBUTE.level_names = {
  untrained = 'attribute.rank.untrained',
  trained = 'attribute.rank.trained',
  expert = 'attribute.rank.expert',
  master = 'attribute.rank.master',
  legendary = 'attribute.rank.legendary'
}
ATTRIBUTE.levels = {
  untrained = 'attribute.lore.untrained',
  trained = 'attribute.lore.trained',
  expert = 'attribute.lore.expert',
  master = 'attribute.lore.master',
  legendary = 'attribute.lore.legendary'
}
