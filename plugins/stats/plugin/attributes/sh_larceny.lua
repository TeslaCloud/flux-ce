--- Larceny skill: picking locks and pockets. Its key stat is reflexes, whose level every roll
-- of the skill adds to the d20 together with the proficiency of the rank, from untrained (0)
-- to legendary (4). The skill is listed under reflexes in the Attributes tab.

ATTRIBUTE.name = 'attribute.larceny.title'
ATTRIBUTE.description = 'attribute.larceny.description'
ATTRIBUTE.icon = 'fa-unlock'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'reflexes'
ATTRIBUTE.category = 'attribute.reflexes.title'
ATTRIBUTE.min = 0
ATTRIBUTE.max = 4
ATTRIBUTE.default = 0
ATTRIBUTE.has_progress = false
ATTRIBUTE.level_order = { 'untrained', 'trained', 'expert', 'master', 'legendary' }
ATTRIBUTE.level_names = {
  untrained = 'attribute.rank.untrained',
  trained = 'attribute.rank.trained',
  expert = 'attribute.rank.expert',
  master = 'attribute.rank.master',
  legendary = 'attribute.rank.legendary'
}
ATTRIBUTE.levels = {
  untrained = 'attribute.larceny.untrained',
  trained = 'attribute.larceny.trained',
  expert = 'attribute.larceny.expert',
  master = 'attribute.larceny.master',
  legendary = 'attribute.larceny.legendary'
}
