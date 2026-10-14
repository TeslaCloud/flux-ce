--- Medicine skill: treating wounds and illnesses. Its key stat is intelligence, whose level
-- every roll of the skill adds to the d20 together with the proficiency of the rank, from
-- untrained (0) to legendary (4). The skill is listed under intelligence in the Attributes
-- tab.

ATTRIBUTE.name = 'attribute.medicine.title'
ATTRIBUTE.description = 'attribute.medicine.description'
ATTRIBUTE.icon = 'fa-kit-medical'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'intelligence'
ATTRIBUTE.category = 'attribute.intelligence.title'
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
  untrained = 'attribute.medicine.untrained',
  trained = 'attribute.medicine.trained',
  expert = 'attribute.medicine.expert',
  master = 'attribute.medicine.master',
  legendary = 'attribute.medicine.legendary'
}
