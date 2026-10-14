--- Crafting skill: building and repairing equipment. Its key stat is intelligence, whose level
-- every roll of the skill adds to the d20 together with the proficiency of the rank, from
-- untrained (0) to legendary (4). The skill is listed under intelligence on the character
-- sheet.

SKILL.name = 'skill.crafting.title'
SKILL.description = 'skill.crafting.description'
SKILL.icon = 'fa-hammer'
SKILL.attribute = 'intelligence'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.crafting.untrained',
  trained = 'skill.crafting.trained',
  expert = 'skill.crafting.expert',
  master = 'skill.crafting.master',
  legendary = 'skill.crafting.legendary'
}
