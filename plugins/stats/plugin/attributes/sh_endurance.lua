--- Endurance stat: the fitness and toughness of a character, from -3 (terrible) to 5 (legendary);
-- a new character picks at most 3 (superb). The level is the modifier it adds to a roll.
-- Every level slows the drain of stamina and speeds up its regeneration by the
-- `stats_endurance_stamina` config, and speeds up health regeneration and the recovery of
-- hurt limbs by the `stats_endurance_recovery` config. Levels below zero do the opposite.

ATTRIBUTE.name = 'attribute.endurance.title'
ATTRIBUTE.description = 'attribute.endurance.description'
ATTRIBUTE.icon = 'flux/icons/hearts.png'
ATTRIBUTE.min = -3
ATTRIBUTE.max = 5
ATTRIBUTE.creation_max = 3
ATTRIBUTE.default = 0
ATTRIBUTE.levels = {
  legendary = 'attribute.endurance.legendary',
  heroic = 'attribute.endurance.heroic',
  superb = 'attribute.endurance.superb',
  great = 'attribute.endurance.great',
  good = 'attribute.endurance.good',
  fair = 'attribute.endurance.fair',
  mediocre = 'attribute.endurance.mediocre',
  poor = 'attribute.endurance.poor',
  terrible = 'attribute.endurance.terrible'
}

ATTRIBUTE.effects = {
  Stats:percent_effect('ui.effect.stamina_drain', 'stats_endurance_stamina', true, || -> Stamina != nil),
  Stats:percent_effect('ui.effect.stamina_regen', 'stats_endurance_stamina', false, || -> Stamina != nil),
  Stats:percent_effect('ui.effect.health_regen', 'stats_endurance_recovery', false, function()
    return Damage != nil and Config.get('health_regen') == true
  end),
  Stats:percent_effect('ui.effect.limb_recovery', 'stats_endurance_recovery', false, function()
    return Limbs != nil and Limbs:is_enabled() and (tonumber(Config.get('limbs_recovery')) or 0) > 0
  end)
}
