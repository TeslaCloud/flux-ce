--- Marksmanship skill: accuracy with firearms and thrown weapons. Its key stat is reflexes,
-- whose level every roll of the skill adds to the d20 together with the proficiency of the
-- rank, from untrained (0) to legendary (4). The skill is listed under reflexes in the
-- Attributes tab.

ATTRIBUTE.name = 'attribute.marksmanship.title'
ATTRIBUTE.description = 'attribute.marksmanship.description'
ATTRIBUTE.icon = 'fa-crosshairs'
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
  untrained = 'attribute.marksmanship.untrained',
  trained = 'attribute.marksmanship.trained',
  expert = 'attribute.marksmanship.expert',
  master = 'attribute.marksmanship.master',
  legendary = 'attribute.marksmanship.legendary'
}
