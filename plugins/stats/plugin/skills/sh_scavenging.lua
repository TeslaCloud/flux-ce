--- Scavenging skill: searching ruins and refuse for supplies. Its key stat is perception, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under perception on the character
-- sheet.

SKILL.name = 'skill.scavenging.title'
SKILL.description = 'skill.scavenging.description'
SKILL.icon = 'fa-box-open'
SKILL.attribute = 'perception'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.scavenging.untrained',
  trained = 'skill.scavenging.trained',
  expert = 'skill.scavenging.expert',
  master = 'skill.scavenging.master',
  legendary = 'skill.scavenging.legendary'
}
