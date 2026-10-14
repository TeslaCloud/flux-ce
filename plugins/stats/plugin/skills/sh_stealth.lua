--- Stealth skill: moving unseen and unheard. Its key stat is reflexes, whose level every roll
-- of the skill adds to the d20 together with the proficiency of the rank, from untrained (0)
-- to legendary (4). The skill is listed under reflexes on the character sheet.

SKILL.name = 'skill.stealth.title'
SKILL.description = 'skill.stealth.description'
SKILL.icon = 'fa-user-ninja'
SKILL.attribute = 'reflexes'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.stealth.untrained',
  trained = 'skill.stealth.trained',
  expert = 'skill.stealth.expert',
  master = 'skill.stealth.master',
  legendary = 'skill.stealth.legendary'
}
