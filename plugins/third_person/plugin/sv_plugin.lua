--- Server side of the Third Person plugin: the `fl_third_person` console command, which
-- toggles the view of the player who runs it, and the raising and lowering of the weapon of
-- a player in third person control.
--
-- While the control is in effect, the weapon is raised while the player aims or fires and
-- lowered `ThirdPerson.raise_grace` seconds after they last did; this overrides the reload
-- key toggle of the Raise Weapon plugin. When the control ends (the view is turned off, the
-- player enters a vehicle, starts noclipping or an animation and so on) the weapon is left
-- as it is: a raised weapon stays raised until the player lowers it with the reload key or
-- switches weapons, or until the control resumes and the raise window has run out. Lowering
-- it there would play the lower gesture on every vehicle entry or animation for nothing.
-- A weapon that is raised when the control starts gets the full raise window before it is
-- lowered, so that turning the view on does not lower it at once.

concommand.Add('fl_third_person', function(actor)
  if !IsValid(actor) then return end

  actor:set_nv('fl_third_person', !actor:get_nv('fl_third_person', false))
end)

--- How long, in seconds, a raise or lower that the PlayerCanRaiseWeapon hook has refused is
-- not asked for again.
local retry_delay = 0.5

--- Raises or lowers the active weapon of a player in third person control to match their
-- raise window: raised until the `fl_tp_raise_until` field of the player, lowered after it.
-- `Player:set_weapon_raised` is only called when the networked state differs from the
-- wanted one, so that the gestures and the fire blocking of the Raise Weapon plugin run once
-- per change, and a change that the PlayerCanRaiseWeapon hook refuses is not asked for again
-- for half a second. Does nothing without the Raise Weapon plugin, while its
-- `raise_gun_enabled` config is off, without a valid weapon and for the weapons whose
-- state is fixed (the physgun, gravity gun, tool gun, camera and the weapons marked as
-- always or never raised). The caller checks that the control is in effect.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the call]
function ThirdPerson:update_raise(actor, cur_time)
  if !RaiseGun or !Config.get('raise_gun_enabled', true) then return end

  local weapon = actor:GetActiveWeapon()

  if !IsValid(weapon) or RaiseGun:get_fixed_state(weapon) != nil then return end

  local wanted = cur_time < (actor.fl_tp_raise_until or 0)

  if actor:GetDTBool(BOOL_WEAPON_RAISED) == wanted then return end
  if (actor.fl_tp_raise_retry or 0) > cur_time then return end

  actor:set_weapon_raised(wanted)

  if actor:GetDTBool(BOOL_WEAPON_RAISED) != wanted then
    actor.fl_tp_raise_retry = cur_time + retry_delay
  end
end

--- Lowers the weapon of a player in third person control once their raise window has run
-- out, and raises a weapon they have switched to while it is still open. Raising on input
-- is done at once by the `StartCommand` handler; this catches what happens between inputs.
-- When the control starts with the weapon raised, the raise window is opened so that the
-- weapon stays up for `ThirdPerson.raise_grace` seconds rather than being lowered at once.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function ThirdPerson:PlayerThink(actor, cur_time)
  if !RaiseGun then return end

  local controlling = self:is_controlling(actor)

  if controlling and !actor.fl_tp_controlling and actor:GetDTBool(BOOL_WEAPON_RAISED) then
    actor.fl_tp_raise_until = math.max(actor.fl_tp_raise_until or 0, cur_time + self.raise_grace)
  end

  actor.fl_tp_controlling = controlling

  if controlling then
    self:update_raise(actor, cur_time)
  end
end
