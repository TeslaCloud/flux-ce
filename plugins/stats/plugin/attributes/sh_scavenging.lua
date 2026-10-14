--- Scavenging skill: searching ruins and refuse for supplies. Its key stat is perception, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under perception on the character
-- sheet.

ATTRIBUTE.name = 'attribute.scavenging.title'
ATTRIBUTE.description = 'attribute.scavenging.description'
ATTRIBUTE.icon = 'fa-box-open'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'perception'
ATTRIBUTE.category = 'attribute.perception.title'
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
  untrained = 'attribute.scavenging.untrained',
  trained = 'attribute.scavenging.trained',
  expert = 'attribute.scavenging.expert',
  master = 'attribute.scavenging.master',
  legendary = 'attribute.scavenging.legendary'
}
