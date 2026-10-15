--- Shared hooks of the Third Person plugin: reads the aim and fire input out of the commands
-- of a player in third person control, keeps track of how long their weapon is to stay
-- raised and takes the secondary attack away from the weapons whose secondary attack the aim
-- takes. On the client it also predicts the raised state of the local player's weapon, so
-- that the Raise Weapon plugin lets the first shot through.
--
-- A command is sent to the server before the client runs it through StartCommand, so the
-- server sees the secondary attack the way the player pressed it and learns of the aim from
-- it; the client takes the key out of its own copy of the command only so that the weapon
-- does not predict a secondary attack.

if CLIENT then
  --- CurTime() until which the local player's weapon is predicted to be raised: the last aim
  -- or fire input of the local player plus `ThirdPerson.raise_grace`. Mirrors the
  -- `fl_tp_raise_until` field the server keeps on every player.
  ThirdPerson.local_raise_until = ThirdPerson.local_raise_until or 0

  --- Predicts the raised state of the local player's weapon while third person control is
  -- in effect: the weapon counts as raised while the aim or fire key is held and for
  -- `ThirdPerson.raise_grace` seconds after it was last held, which the server makes true
  -- shortly after.
  -- The keys are taken from `ThirdPerson.aiming` and `ThirdPerson.firing`, which the
  -- `CreateMove` handler reads out of every command before any StartCommand handler sees
  -- it. They cannot be read in this plugin's own StartCommand handler: the Raise Weapon
  -- plugin loads first, and its handler takes the attack keys out of the command while the
  -- weapon counts as lowered. Answering true as soon as a key is held keeps the keys in the
  -- command, so that the first shot is not lost.
  -- Nothing is answered for other players, outside of the control, while the
  -- `weapon_raise_enabled` config is off or while the player is running and the
  -- `sprint_lowers_weapon` config keeps the weapon lowered, so that the normal state
  -- applies.
  -- @param actor [Player]
  -- @param weapon [Weapon active weapon of the player, one that can be raised and lowered]
  -- @return [Boolean true while the weapon is predicted to be raised, nil otherwise]
  function ThirdPerson:ShouldWeaponBeRaised(actor, weapon)
    if actor != PLAYER or !self:is_controlling(actor) then return end
    if !Config.get('weapon_raise_enabled', true) then return end
    if Config.get('sprint_lowers_weapon') and actor:running() then return end

    if self.aiming or self.firing or CurTime() < self.local_raise_until then
      return true
    end
  end
end

--- Reads the aim and fire input out of the commands of a player in third person control and
-- takes the secondary attack out of them for the weapons whose secondary attack the aim
-- takes, so that aiming never fires it. The fists, physgun, gravity gun, tool gun, camera
-- and the weapons the Raise Weapon plugin marks as always or never raised keep it.
-- While the player aims or fires, the raise window is opened again: on the server the
-- `fl_tp_raise_until` field of the player is set to `ThirdPerson.raise_grace` seconds from
-- now and a lowered weapon is raised at once (see `ThirdPerson:update_raise`), on the client
-- `ThirdPerson.local_raise_until` is set for the local player.
-- @param actor [Player]
-- @param user_cmd [CUserCmd]
function ThirdPerson:StartCommand(actor, user_cmd)
  if CLIENT and actor != PLAYER then return end
  if !self:is_controlling(actor) then return end

  local weapon = actor:GetActiveWeapon()
  local aiming, firing = self:read_input(user_cmd:GetButtons(), weapon)

  if aiming or firing then
    local cur_time = CurTime()

    if SERVER then
      actor.fl_tp_raise_until = cur_time + self.raise_grace

      self:update_raise(actor, cur_time)
    else
      self.local_raise_until = cur_time + self.raise_grace
    end
  end

  if self:owns_secondary_attack(weapon) then
    user_cmd:RemoveKey(IN_ATTACK2)
  end
end
