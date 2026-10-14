--- Survival skill: finding food, water and shelter outdoors. Its key stat is endurance, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under endurance on the character
-- sheet.

SKILL.name = 'skill.survival.title'
SKILL.description = 'skill.survival.description'
SKILL.icon = 'fa-campground'
SKILL.attribute = 'endurance'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.survival.untrained',
  trained = 'skill.survival.trained',
  expert = 'skill.survival.expert',
  master = 'skill.survival.master',
  legendary = 'skill.survival.legendary'
}
