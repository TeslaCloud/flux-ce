--- Intimidation skill: coercing others through threats and fear. Its key stat is charisma,
-- whose level every roll of the skill adds to the d20 together with the proficiency of the
-- rank, from untrained (0) to legendary (4). The skill is listed under charisma on the
-- character sheet.

SKILL.name = 'skill.intimidation.title'
SKILL.description = 'skill.intimidation.description'
SKILL.icon = 'fa-face-angry'
SKILL.attribute = 'charisma'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.intimidation.untrained',
  trained = 'skill.intimidation.trained',
  expert = 'skill.intimidation.expert',
  master = 'skill.intimidation.master',
  legendary = 'skill.intimidation.legendary'
}
