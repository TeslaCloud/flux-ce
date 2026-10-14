--- Streetwise skill: knowing the streets and the black market. Its key stat is charisma, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under charisma on the character
-- sheet.

SKILL.name = 'skill.streetwise.title'
SKILL.description = 'skill.streetwise.description'
SKILL.icon = 'fa-city'
SKILL.attribute = 'charisma'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.streetwise.untrained',
  trained = 'skill.streetwise.trained',
  expert = 'skill.streetwise.expert',
  master = 'skill.streetwise.master',
  legendary = 'skill.streetwise.legendary'
}
