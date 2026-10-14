--- Lore skill: knowledge of history, science and culture. Its key stat is intelligence, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under intelligence on the
-- character sheet.

SKILL.name = 'skill.lore.title'
SKILL.description = 'skill.lore.description'
SKILL.icon = 'fa-book-open'
SKILL.attribute = 'intelligence'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.lore.untrained',
  trained = 'skill.lore.trained',
  expert = 'skill.lore.expert',
  master = 'skill.lore.master',
  legendary = 'skill.lore.legendary'
}
