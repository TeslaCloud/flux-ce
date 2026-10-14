--- Medicine skill: treating wounds and illnesses. Its key stat is intelligence, whose level
-- every roll of the skill adds to the d20 together with the proficiency of the rank, from
-- untrained (0) to legendary (4). The skill is listed under intelligence on the character
-- sheet.

SKILL.name = 'skill.medicine.title'
SKILL.description = 'skill.medicine.description'
SKILL.icon = 'fa-kit-medical'
SKILL.attribute = 'intelligence'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.medicine.untrained',
  trained = 'skill.medicine.trained',
  expert = 'skill.medicine.expert',
  master = 'skill.medicine.master',
  legendary = 'skill.medicine.legendary'
}
