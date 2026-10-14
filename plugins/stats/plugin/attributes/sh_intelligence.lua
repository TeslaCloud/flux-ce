--- Intelligence stat: the strength of mind of a character, from -3 (terrible) to 5 (legendary);
-- a new character picks at most 3 (superb). The level is the modifier it adds to a roll.
-- Every level raises the progress gained in skills that progress by the
-- `stats_intelligence_learning` config. Levels below zero lower it.

ATTRIBUTE.name = 'attribute.intelligence.title'
ATTRIBUTE.description = 'attribute.intelligence.description'
ATTRIBUTE.icon = 'flux/icons/bookmarklet.png'
ATTRIBUTE.type = ATTRIBUTE_STAT
ATTRIBUTE.min = -3
ATTRIBUTE.max = 5
ATTRIBUTE.creation_max = 3
ATTRIBUTE.default = 0
ATTRIBUTE.has_progress = false
ATTRIBUTE.levels = {
  legendary = 'attribute.intelligence.legendary',
  heroic = 'attribute.intelligence.heroic',
  superb = 'attribute.intelligence.superb',
  great = 'attribute.intelligence.great',
  good = 'attribute.intelligence.good',
  fair = 'attribute.intelligence.fair',
  mediocre = 'attribute.intelligence.mediocre',
  poor = 'attribute.intelligence.poor',
  terrible = 'attribute.intelligence.terrible'
}

ATTRIBUTE.effects = {
  Stats:percent_effect('ui.effect.skill_progress', 'stats_intelligence_learning', false, function()
    for k, v in pairs(Attributes.get_by_type(ATTRIBUTE_SKILL)) do
      if v.has_progress != false then
        return true
      end
    end

    return false
  end)
}
