--- Fortitude skill: resisting poison, disease and hardship. Its key stat is endurance, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under endurance on the character
-- sheet.

ATTRIBUTE.name = 'attribute.fortitude.title'
ATTRIBUTE.description = 'attribute.fortitude.description'
ATTRIBUTE.icon = 'fa-shield-halved'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'endurance'
ATTRIBUTE.category = 'attribute.endurance.title'
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
  untrained = 'attribute.fortitude.untrained',
  trained = 'attribute.fortitude.trained',
  expert = 'attribute.fortitude.expert',
  master = 'attribute.fortitude.master',
  legendary = 'attribute.fortitude.legendary'
}
