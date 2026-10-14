--- Focus skill: concentrating through pain and distraction. Its key stat is determination,
-- whose level every roll of the skill adds to the d20 together with the proficiency of the
-- rank, from untrained (0) to legendary (4). The skill is listed under determination in the
-- Attributes tab.

ATTRIBUTE.name = 'attribute.focus.title'
ATTRIBUTE.description = 'attribute.focus.description'
ATTRIBUTE.icon = 'fa-bullseye'
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
  untrained = 'attribute.focus.untrained',
  trained = 'attribute.focus.trained',
  expert = 'attribute.focus.expert',
  master = 'attribute.focus.master',
  legendary = 'attribute.focus.legendary'
}
