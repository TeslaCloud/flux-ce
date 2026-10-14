--- Stealth skill: moving unseen and unheard. Its key stat is reflexes, whose level every roll
-- of the skill adds to the d20 together with the proficiency of the rank, from untrained (0)
-- to legendary (4). The skill is listed under reflexes on the character sheet.

ATTRIBUTE.name = 'attribute.stealth.title'
ATTRIBUTE.description = 'attribute.stealth.description'
ATTRIBUTE.icon = 'fa-user-ninja'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'reflexes'
ATTRIBUTE.category = 'attribute.reflexes.title'
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
  untrained = 'attribute.stealth.untrained',
  trained = 'attribute.stealth.trained',
  expert = 'attribute.stealth.expert',
  master = 'attribute.stealth.master',
  legendary = 'attribute.stealth.legendary'
}
