--- Composure skill: keeping calm under pressure. Its key stat is determination, whose level
-- every roll of the skill adds to the d20 together with the proficiency of the rank, from
-- untrained (0) to legendary (4). The skill is listed under determination on the character
-- sheet.

SKILL.name = 'skill.composure.title'
SKILL.description = 'skill.composure.description'
SKILL.icon = 'fa-scale-balanced'
SKILL.attribute = 'determination'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.composure.untrained',
  trained = 'skill.composure.trained',
  expert = 'skill.composure.expert',
  master = 'skill.composure.master',
  legendary = 'skill.composure.legendary'
}
