--- Close Combat skill: fighting at arm's length with fists and melee weapons. Its key stat is
-- strength, whose level every roll of the skill adds to the d20 together with the proficiency
-- of the rank, from untrained (0) to legendary (4). The skill is listed under strength on the
-- character sheet.

ATTRIBUTE.name = 'attribute.close_combat.title'
ATTRIBUTE.description = 'attribute.close_combat.description'
ATTRIBUTE.icon = 'fa-hand-fist'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'strength'
ATTRIBUTE.category = 'attribute.strength.title'
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
  untrained = 'attribute.close_combat.untrained',
  trained = 'attribute.close_combat.trained',
  expert = 'attribute.close_combat.expert',
  master = 'attribute.close_combat.master',
  legendary = 'attribute.close_combat.legendary'
}
