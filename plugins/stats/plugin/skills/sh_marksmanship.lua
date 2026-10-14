--- Marksmanship skill: accuracy with firearms and thrown weapons. Its key stat is reflexes,
-- whose level every roll of the skill adds to the d20 together with the proficiency of the
-- rank, from untrained (0) to legendary (4). The skill is listed under reflexes on the
-- character sheet.

SKILL.name = 'skill.marksmanship.title'
SKILL.description = 'skill.marksmanship.description'
SKILL.icon = 'fa-crosshairs'
SKILL.attribute = 'reflexes'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.marksmanship.untrained',
  trained = 'skill.marksmanship.trained',
  expert = 'skill.marksmanship.expert',
  master = 'skill.marksmanship.master',
  legendary = 'skill.marksmanship.legendary'
}
