--- Observation skill: spotting details and hidden things. Its key stat is perception, whose
-- level every roll of the skill adds to the d20 together with the proficiency of the rank,
-- from untrained (0) to legendary (4). The skill is listed under perception in the Attributes
-- tab.

ATTRIBUTE.name = 'attribute.observation.title'
ATTRIBUTE.description = 'attribute.observation.description'
ATTRIBUTE.icon = 'fa-binoculars'
ATTRIBUTE.type = ATTRIBUTE_SKILL
ATTRIBUTE.attribute = 'perception'
ATTRIBUTE.category = 'attribute.perception.title'
ATTRIBUTE.min = 0
ATTRIBUTE.max = 4
ATTRIBUTE.default = 0
ATTRIBUTE.has_progress = false
ATTRIBUTE.level_order = { 'untrained', 'trained', 'expert', 'master', 'legendary' }
ATTRIBUTE.level_names = {
  untrained = 'attribute.rank.untrained',
  trained = 'attribute.rank.trained',
  expert = 'attribute.rank.expert',
  master = 'attribute.rank.master',
  legendary = 'attribute.rank.legendary'
}
ATTRIBUTE.levels = {
  untrained = 'attribute.observation.untrained',
  trained = 'attribute.observation.trained',
  expert = 'attribute.observation.expert',
  master = 'attribute.observation.master',
  legendary = 'attribute.observation.legendary'
}
