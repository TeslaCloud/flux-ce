--- Observation skill: spotting details and hidden things. Its key stat is perception, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under perception on the character
-- sheet.

SKILL.name = 'skill.observation.title'
SKILL.description = 'skill.observation.description'
SKILL.icon = 'fa-binoculars'
SKILL.attribute = 'perception'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.observation.untrained',
  trained = 'skill.observation.trained',
  expert = 'skill.observation.expert',
  master = 'skill.observation.master',
  legendary = 'skill.observation.legendary'
}
