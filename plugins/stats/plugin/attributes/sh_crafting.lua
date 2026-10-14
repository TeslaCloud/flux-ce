--- Crafting skill: building and repairing equipment. Its key stat is intelligence, whose level
-- every roll of the skill adds to the d20 together with the proficiency of the rank, from
-- untrained (0) to legendary (4). The skill is listed under intelligence on the character
-- sheet.

ATTRIBUTE.name = 'attribute.crafting.title'
ATTRIBUTE.description = 'attribute.crafting.description'
ATTRIBUTE.icon = 'fa-hammer'
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
  untrained = 'attribute.crafting.untrained',
  trained = 'attribute.crafting.trained',
  expert = 'attribute.crafting.expert',
  master = 'attribute.crafting.master',
  legendary = 'attribute.crafting.legendary'
}
