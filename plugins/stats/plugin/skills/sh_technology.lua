--- Technology skill: electronics, computers and machinery. Its key stat is intelligence, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under intelligence on the
-- character sheet.

SKILL.name = 'skill.technology.title'
SKILL.description = 'skill.technology.description'
SKILL.icon = 'fa-microchip'
SKILL.attribute = 'intelligence'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.technology.untrained',
  trained = 'skill.technology.trained',
  expert = 'skill.technology.expert',
  master = 'skill.technology.master',
  legendary = 'skill.technology.legendary'
}
