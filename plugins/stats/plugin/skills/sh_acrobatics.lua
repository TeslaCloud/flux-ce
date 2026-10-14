--- Acrobatics skill: balance, tumbling and dodging. Its key stat is reflexes, whose level every
-- roll of the skill adds to the d20 together with the proficiency of the rank, from untrained
-- (0) to legendary (4). The skill is listed under reflexes on the character sheet.

SKILL.name = 'skill.acrobatics.title'
SKILL.description = 'skill.acrobatics.description'
SKILL.icon = 'fa-person-falling'
SKILL.attribute = 'reflexes'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.acrobatics.untrained',
  trained = 'skill.acrobatics.trained',
  expert = 'skill.acrobatics.expert',
  master = 'skill.acrobatics.master',
  legendary = 'skill.acrobatics.legendary'
}
