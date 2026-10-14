--- Focus skill: concentrating through pain and distraction. Its key stat is determination,
-- whose level every roll of the skill adds to the d20 together with the proficiency of the
-- rank, from untrained (0) to legendary (4). The skill is listed under determination on the
-- character sheet.

SKILL.name = 'skill.focus.title'
SKILL.description = 'skill.focus.description'
SKILL.icon = 'fa-bullseye'
SKILL.attribute = 'determination'
SKILL.max = 4
SKILL.ranks = {
  untrained = 'skill.focus.untrained',
  trained = 'skill.focus.trained',
  expert = 'skill.focus.expert',
  master = 'skill.focus.master',
  legendary = 'skill.focus.legendary'
}
