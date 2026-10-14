--- Deception skill: lying, bluffing and misdirection. Its key stat is charisma, whose level
-- every roll of the skill adds to the d20 together with the proficiency of the rank, from
-- untrained (0) to legendary (4). The skill is listed under charisma in the Attributes tab.

ATTRIBUTE.name = 'attribute.deception.title'
ATTRIBUTE.description = 'attribute.deception.description'
ATTRIBUTE.icon = 'fa-masks-theater'
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
  untrained = 'attribute.deception.untrained',
  trained = 'attribute.deception.trained',
  expert = 'attribute.deception.expert',
  master = 'attribute.deception.master',
  legendary = 'attribute.deception.legendary'
}
