--- Streetwise skill: knowing the streets and the black market. Its key stat is charisma, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under charisma in the Attributes
-- tab.

ATTRIBUTE.name = 'attribute.streetwise.title'
ATTRIBUTE.description = 'attribute.streetwise.description'
ATTRIBUTE.icon = 'fa-city'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'charisma'
ATTRIBUTE.category = 'attribute.charisma.title'
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
  untrained = 'attribute.streetwise.untrained',
  trained = 'attribute.streetwise.trained',
  expert = 'attribute.streetwise.expert',
  master = 'attribute.streetwise.master',
  legendary = 'attribute.streetwise.legendary'
}
