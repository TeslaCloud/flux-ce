--- Athletics skill: running, climbing, jumping and swimming. Its key stat is strength, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under strength on the character
-- sheet.

SKILL.name = 'skill.athletics.title'
SKILL.description = 'skill.athletics.description'
SKILL.icon = 'fa-person-running'
SKILL.attribute = 'strength'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.athletics.untrained',
  trained = 'skill.athletics.trained',
  expert = 'skill.athletics.expert',
  master = 'skill.athletics.master',
  legendary = 'skill.athletics.legendary'
}
