--- Deception skill: lying, bluffing and misdirection. Its key stat is charisma, whose level
-- every roll of the skill adds to the d20 together with the proficiency of the rank, from
-- untrained (0) to legendary (4). The skill is listed under charisma on the character sheet.

SKILL.name = 'skill.deception.title'
SKILL.description = 'skill.deception.description'
SKILL.icon = 'fa-masks-theater'
SKILL.attribute = 'charisma'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.deception.untrained',
  trained = 'skill.deception.trained',
  expert = 'skill.deception.expert',
  master = 'skill.deception.master',
  legendary = 'skill.deception.legendary'
}
