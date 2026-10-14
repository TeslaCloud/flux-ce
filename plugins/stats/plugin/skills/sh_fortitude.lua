--- Fortitude skill: resisting poison, disease and hardship. Its key stat is endurance, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under endurance on the character
-- sheet.

SKILL.name = 'skill.fortitude.title'
SKILL.description = 'skill.fortitude.description'
SKILL.icon = 'fa-shield-halved'
SKILL.attribute = 'endurance'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.fortitude.untrained',
  trained = 'skill.fortitude.trained',
  expert = 'skill.fortitude.expert',
  master = 'skill.fortitude.master',
  legendary = 'skill.fortitude.legendary'
}
