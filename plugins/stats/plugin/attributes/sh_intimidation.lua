--- Intimidation skill: coercing others through threats and fear. Its key stat is charisma,
-- whose level every roll of the skill adds to the d20 together with the proficiency of the
-- rank, from untrained (0) to legendary (4). The skill is listed under charisma in the
-- Attributes tab.

ATTRIBUTE.name = 'attribute.intimidation.title'
ATTRIBUTE.description = 'attribute.intimidation.description'
ATTRIBUTE.icon = 'fa-face-angry'
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
  untrained = 'attribute.intimidation.untrained',
  trained = 'attribute.intimidation.trained',
  expert = 'attribute.intimidation.expert',
  master = 'attribute.intimidation.master',
  legendary = 'attribute.intimidation.legendary'
}
