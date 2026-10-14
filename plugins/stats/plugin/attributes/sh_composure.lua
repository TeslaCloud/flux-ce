--- Composure skill: keeping calm under pressure. Its key stat is determination, whose level
-- every roll of the skill adds to the d20 together with the proficiency of the rank, from
-- untrained (0) to legendary (4). The skill is listed under determination in the Attributes
-- tab.

ATTRIBUTE.name = 'attribute.composure.title'
ATTRIBUTE.description = 'attribute.composure.description'
ATTRIBUTE.icon = 'fa-scale-balanced'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'determination'
ATTRIBUTE.category = 'attribute.determination.title'
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
  untrained = 'attribute.composure.untrained',
  trained = 'attribute.composure.trained',
  expert = 'attribute.composure.expert',
  master = 'attribute.composure.master',
  legendary = 'attribute.composure.legendary'
}
