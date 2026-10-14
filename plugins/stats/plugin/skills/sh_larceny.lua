--- Larceny skill: picking locks and pockets. Its key stat is reflexes, whose level every roll
-- of the skill adds to the d20 together with the proficiency of the rank, from untrained (0)
-- to legendary (4). The skill is listed under reflexes on the character sheet.

SKILL.name = 'skill.larceny.title'
SKILL.description = 'skill.larceny.description'
SKILL.icon = 'fa-unlock'
SKILL.attribute = 'reflexes'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.larceny.untrained',
  trained = 'skill.larceny.trained',
  expert = 'skill.larceny.expert',
  master = 'skill.larceny.master',
  legendary = 'skill.larceny.legendary'
}
