--- Technology skill: electronics, computers and machinery. Its key stat is intelligence, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under intelligence on the
-- character sheet.

ATTRIBUTE.name = 'attribute.technology.title'
ATTRIBUTE.description = 'attribute.technology.description'
ATTRIBUTE.icon = 'fa-microchip'
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
  untrained = 'attribute.technology.untrained',
  trained = 'attribute.technology.trained',
  expert = 'attribute.technology.expert',
  master = 'attribute.technology.master',
  legendary = 'attribute.technology.legendary'
}
