--- Persuasion skill: convincing others through reason and charm. Its key stat is charisma,
-- whose level every roll of the skill adds to the d20 together with the proficiency of the
-- rank, from untrained (0) to legendary (4). The skill is listed under charisma on the
-- character sheet.

SKILL.name = 'skill.persuasion.title'
SKILL.description = 'skill.persuasion.description'
SKILL.icon = 'fa-handshake'
SKILL.attribute = 'charisma'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.persuasion.untrained',
  trained = 'skill.persuasion.trained',
  expert = 'skill.persuasion.expert',
  master = 'skill.persuasion.master',
  legendary = 'skill.persuasion.legendary'
}
