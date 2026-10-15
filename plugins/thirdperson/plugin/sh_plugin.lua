--- Third Person gives players a GTA V style camera behind their character.
-- The view is toggled with the `fl_third_person` console command, which the plugin binds to
-- the P key by default, and the state is networked as the `fl_third_person` variable of the
-- player.
--
-- While the view is on and the player is on foot, the camera orbits the character on its
-- own, straight behind them. The view angles of the player always point from their eyes at
-- what the middle of the screen shows, so shots, the use key, the tool gun, spawned props and
-- everything else that follows the eyes of the player go where the camera looks. Only the
-- model of the character turns on its own: it faces the way the player moves and keeps
-- facing that way when they stop, so that turning the mouse turns the camera and not the
-- character.
--
-- Holding the secondary attack aims: the camera moves in over a shoulder and the weapon is
-- raised by itself, so that the reload key need not be held. The primary attack fires from
-- the hip and raises the weapon the same way, without the camera moving in. While the weapon
-- is raised the character faces where the player aims, and it is lowered again a moment
-- after the player stops aiming and firing. The `fl_switch_shoulder` command moves the aiming
-- camera to the other shoulder.
--
-- The secondary attack is taken by the aim only for the weapons that can be raised and
-- lowered: the fists, the physgun, gravity gun, tool gun and camera, and the weapons the
-- Raise Weapon plugin marks as always or never raised, keep their own secondary attack.
--
-- Nothing of the control is done while the player is dead, in a vehicle, noclipping,
-- observing, seeing through another entity or playing an animation of the Animations plugin.
-- During an animation the camera keeps orbiting the locked character; otherwise it only
-- follows the view angles of the player. The model of every player in control is turned the
-- same way on the server and on every client, from their movement and the networked raised
-- state of their weapon.
-- @module [ThirdPerson]

PLUGIN:set_global('ThirdPerson')

--- How long, in seconds, the weapon stays raised after the last aim or fire input.
ThirdPerson.raise_grace = 1.5

local band = bit.band

--- Weapons whose secondary attack the aim never takes when the Raise Weapon plugin, which
-- knows about the fixed state of a weapon, is not loaded.
local blocked_weapons = {
  ['weapon_physgun'] = true,
  ['gmod_tool'] = true,
  ['gmod_camera'] = true,
  ['weapon_physcannon'] = true
}

--- Checks whether a player has the third person view turned on. The camera is shown for as
-- long as this is true, whatever the player is doing.
-- @param client [Player]
-- @return [Boolean]
function ThirdPerson:is_enabled(client)
  return client:get_nv('fl_third_person', false) == true
end

--- Checks whether the third person control of a player is in effect: the view is on and the
-- player is alive and on foot, outside a vehicle, not noclipping or observing, seeing through
-- their own eyes rather than another entity and not playing an animation of the Animations
-- plugin. Only then does the camera orbit on its own, the character face the way they move
-- and the aim take over the secondary attack.
-- @param client [Player]
-- @return [Boolean]
function ThirdPerson:is_controlling(client)
  if !IsValid(client) or !self:is_enabled(client) then
    return false
  end

  if !client:Alive() or client:InVehicle() or client:GetMoveType() != MOVETYPE_WALK then
    return false
  end

  if client:get_nv('observer') or client:get_nv('fl_animation') then
    return false
  end

  local view_entity = client:GetViewEntity()

  if IsValid(view_entity) and view_entity != client then
    return false
  end

  return true
end

--- Checks whether the aim takes the secondary attack of a weapon: whether the weapon can be
-- raised and lowered. Without a valid weapon the aim takes it. The fists keep theirs, since
-- the Pickup Objects plugin picks things up with it.
-- @param weapon [Weapon active weapon of the player, which may not be valid]
-- @return [Boolean false for the fists, the physgun, gravity gun, tool gun and camera and
--   for the weapons the Raise Weapon plugin marks as always or never raised]
function ThirdPerson:owns_secondary_attack(weapon)
  if !IsValid(weapon) then
    return true
  end

  if weapon:GetClass():include('fists') then
    return false
  end

  if RaiseGun then
    return RaiseGun:get_fixed_state(weapon) == nil
  end

  return !blocked_weapons[weapon:GetClass()]
end

--- Reads the aim input out of the buttons of a user command.
-- Aiming is the secondary attack held with a weapon whose secondary attack the aim takes;
-- firing is the primary attack held with any weapon. Both raise the weapon and make the model
-- face where the player aims, only the first moves the camera in over the shoulder.
-- @param buttons [Number IN_ button bits of the command]
-- @param weapon [Weapon active weapon of the player, which may not be valid]
-- @return [Boolean aiming, Boolean firing]
function ThirdPerson:read_input(buttons, weapon)
  local aiming = band(buttons, IN_ATTACK2) != 0 and self:owns_secondary_attack(weapon)
  local firing = band(buttons, IN_ATTACK) != 0

  return aiming, firing
end

--- Checks whether the model of a player in third person control faces where they aim rather
-- than the way they move: while their weapon is raised, which includes the tools that are
-- always raised, such as the physgun and the tool gun. On the client the local player also
-- faces their aim as soon as they aim or fire, before the server has raised the weapon.
-- Without the Raise Weapon plugin only the aim and fire input of the local player counts.
-- @param client [Player]
-- @return [Boolean]
function ThirdPerson:faces_aim(client)
  if CLIENT and client == PLAYER and (self.aiming or self.firing) then
    return true
  end

  if client.is_weapon_raised then
    return client:is_weapon_raised()
  end

  return false
end

require_relative 'sh_hooks'
require_relative 'sv_plugin'
require_relative 'cl_plugin'
