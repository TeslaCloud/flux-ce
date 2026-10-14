--- Close Combat skill: fighting at arm's length with fists and melee weapons. Its key stat is
-- strength, whose level every roll of the skill adds to the d20 together with the proficiency
-- of the rank, from untrained (0) to legendary (4). The skill is listed under strength on the
-- character sheet.

SKILL.name = 'skill.close_combat.title'
SKILL.description = 'skill.close_combat.description'
SKILL.icon = 'fa-hand-fist'
SKILL.attribute = 'strength'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.close_combat.untrained',
  trained = 'skill.close_combat.trained',
  expert = 'skill.close_combat.expert',
  master = 'skill.close_combat.master',
  legendary = 'skill.close_combat.legendary'
}
