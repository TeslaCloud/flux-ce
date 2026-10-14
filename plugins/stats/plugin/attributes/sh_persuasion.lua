--- Persuasion skill: convincing others through reason and charm. Its key stat is charisma,
-- whose level every roll of the skill adds to the d20 together with the proficiency of the
-- rank, from untrained (0) to legendary (4). The skill is listed under charisma on the
-- character sheet.

ATTRIBUTE.name = 'attribute.persuasion.title'
ATTRIBUTE.description = 'attribute.persuasion.description'
ATTRIBUTE.icon = 'fa-handshake'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'charisma'
ATTRIBUTE.category = 'attribute.charisma.title'
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
  untrained = 'attribute.persuasion.untrained',
  trained = 'attribute.persuasion.trained',
  expert = 'attribute.persuasion.expert',
  master = 'attribute.persuasion.master',
  legendary = 'attribute.persuasion.legendary'
}
