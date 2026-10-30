--- Server side of the Shared Flashlight plugin: toggles the light when the flashlight key is
-- pressed, puts it out on death, when the flashlight item is unequipped and on the way back
-- to the engine flashlight.

--- Toggles the player's shared flashlight and keeps the engine flashlight from toggling.
-- The engine always asks to turn its flashlight on, since it never gets to turn on, so the
-- player's current state decides which way the toggle goes. The light is only turned on for
-- a living player whom `Player:CanUseFlashlight` allows it, the way the base gamemode decides
-- for the engine flashlight, and who has the item of `SharedFlashlight:has_flashlight_item`;
-- a player toggles it at most five times a second. While the `shared_flashlight_enabled`
-- config is off, only keeps a player without that item from turning the engine flashlight on
-- and otherwise leaves the decision to the base gamemode.
-- @param actor [Player]
-- @param on [Boolean whether the engine flashlight is being turned on]
-- @return [Boolean false while the plugin is enabled or the item is missing, nil otherwise]
function SharedFlashlight:PlayerCanSwitchFlashlight(actor, on)
  if !self:is_enabled() then
    if on and !self:has_flashlight_item(actor) then return false end

    return
  end

  local turn_on = !actor:is_flashlight_on()

  if turn_on and (!actor:Alive() or !actor:CanUseFlashlight() or !self:has_flashlight_item(actor)) then
    return false
  end

  local cur_time = CurTime()

  if (actor.fl_next_flashlight or 0) > cur_time then return false end

  actor.fl_next_flashlight = cur_time + 0.2
  actor:set_flashlight(turn_on)

  return false
end

--- Puts the flashlight of a player out when the item of the `shared_flashlight_item` config
-- is unequipped, whether it is moved, dropped or used up.
-- @param owner [Player]
-- @param item_obj [Item the unequipped item]
function SharedFlashlight:ItemUnequipped(owner, item_obj)
  if IsValid(owner) and item_obj.id == Config.get('shared_flashlight_item', '') and owner:is_flashlight_on() then
    owner:set_flashlight(false)
  end
end

--- Puts the flashlight of a player out when they die.
-- @param victim [Player]
-- @param _inflictor [Entity]
-- @param _attacker [Entity]
function SharedFlashlight:PlayerDeath(victim, _inflictor, _attacker)
  victim:set_flashlight(false)
end

--- Makes sure that a player spawns with their flashlight off. A silent kill, which Flux uses
-- when a player goes back to the main menu or changes character, does not run `PlayerDeath`,
-- so a light that was on at that time would otherwise stay on through the spawn; the engine
-- flashlight is put out as well, in case the engine has kept it from a previous life.
-- @param actor [Player]
function SharedFlashlight:PlayerSpawn(actor)
  if actor:is_flashlight_on() or actor:get_flashlight() then
    actor:set_flashlight(false)
  end
end

--- Removes the light of a player who leaves the server, so that it never outlives them.
-- @param actor [Player]
function SharedFlashlight:PlayerDisconnected(actor)
  local light = actor:get_flashlight()

  if IsValid(light) then
    light:Remove()
  end

  actor.fl_flashlight = nil
end

--- Puts every shared flashlight out when the `shared_flashlight_enabled` config is turned
-- off, so that nobody keeps a light the engine flashlight has taken over from.
-- @param key [String key of the config that has changed]
-- @param _old_value [Any]
-- @param new_value [Any]
function SharedFlashlight:ConfigChanged(key, _old_value, new_value)
  if key == 'shared_flashlight_enabled' and !new_value then
    for _, target in player.Iterator() do
      if IsValid(target:get_flashlight()) then
        target:set_flashlight(false)
      end
    end
  end
end
