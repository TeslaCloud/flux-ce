--- Shared hooks of the Raise Weapon plugin: the data table variable of the raised state, the
-- raised animations and the lookup of the items that give weapons.

--- Forgets which items give which weapons and what the weapons make of their raised state,
-- so that both are looked up again among the items of the schema and the plugins that have
-- just been loaded.
function RaiseGun:SchemaLoaded()
  self.weapon_items = {}
  self.fixed_state_generation += 1
end

--- Tells the animation code whether to use the raised weapon animations for the player.
-- @param actor [Player]
-- @param _model [String the player's model]
-- @return [Boolean whether the player's weapon is raised]
function RaiseGun:ShouldUseRaisedAnimations(actor, _model)
  return actor:is_weapon_raised()
end

--- Registers the WeaponRaised data table boolean on the player.
-- @param target [Player]
function RaiseGun:PlayerSetupDataTables(target)
  target:DTVar('Bool', BOOL_WEAPON_RAISED, 'WeaponRaised')
end
