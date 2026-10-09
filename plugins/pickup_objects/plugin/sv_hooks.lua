--- Server hooks of the Pickup Objects plugin: the keys that pick up, drop and throw, the
-- tick that keeps the holds going, and the rules that deny pickups and protect dragged
-- ragdolls.

local holds = PickupObjects.holds

--- Picks up an object to carry when secondary attack is released while holding fists and
-- nothing else, and drops the held object when reload is released. Ragdolls that are
-- dragged are left to the StartCommand handler, which grabs them as the key is pressed.
-- @param actor [Player]
-- @param key [Number IN_ enum of the released key]
function PickupObjects:KeyRelease(actor, key)
  if key == IN_ATTACK2 and !holds[actor] then
    if self:has_fists(actor) and !self:aims_at_draggable(actor) then
      self:pickup_at_trace(actor)
    end
  elseif key == IN_RELOAD and holds[actor] then
    self:drop_entity(actor)
  end
end

--- Handles the attack keys of a player before the engine and the weapon see them.
-- While the player holds something, pressing primary attack throws it and pressing secondary
-- attack drops it. With the fists out and nothing held, pressing secondary attack while
-- looking at a ragdoll that can be dragged grabs it. Both keys are taken out of the command
-- for as long as something is held, and after the hold has ended for any reason until the
-- keys are let go of, so that the engine does not drop or throw the carried object by itself
-- and the fists do not punch.
-- @param actor [Player]
-- @param user_cmd [CUserCmd]
function PickupObjects:StartCommand(actor, user_cmd)
  local attack, attack2 = user_cmd:KeyDown(IN_ATTACK), user_cmd:KeyDown(IN_ATTACK2)
  local attack_pressed = attack and !actor.pickup_attack_down
  local attack2_pressed = attack2 and !actor.pickup_attack2_down

  actor.pickup_attack_down = attack
  actor.pickup_attack2_down = attack2

  if holds[actor] then
    if attack_pressed then
      self:throw_entity(actor)
    elseif attack2_pressed then
      self:drop_entity(actor)
    end
  elseif actor.pickup_keys_blocked then
    if !attack and !attack2 then
      actor.pickup_keys_blocked = nil

      return
    end
  else
    if !attack2_pressed or !self:has_fists(actor) or !self:aims_at_draggable(actor) then return end
    if !self:pickup_at_trace(actor) or !holds[actor] then return end
  end

  user_cmd:RemoveKey(IN_ATTACK)
  user_cmd:RemoveKey(IN_ATTACK2)
end

--- Updates every hold on each tick, and drops what can no longer be held.
function PickupObjects:Think()
  if next(holds) == nil then return end

  local cur_time = CurTime()
  local lost

  for actor, data in pairs(holds) do
    if !self:update_hold(actor, data, cur_time) then
      lost = lost or {}

      table.insert(lost, actor)
    end
  end

  if lost then
    for k, v in ipairs(lost) do
      self:drop_entity(v, true)
    end
  end
end

--- Denies pickups during the player's one second cooldown. Objects that are to be carried
-- are also denied if they are vehicles, are not moved by physics, cannot move or weigh more
-- than the mass limit of the player.
-- @param actor [Player]
-- @param ent [Entity the object being picked up]
-- @param drag [Boolean whether the object is a ragdoll that is going to be dragged]
-- @return [Boolean false to deny the pickup, nil otherwise]
function PickupObjects:PlayerPickupObject(actor, ent, drag)
  if actor.next_pickup and actor.next_pickup > CurTime() then return false end
  if drag then return end
  if ent:IsVehicle() or ent:GetMoveType() != MOVETYPE_VPHYSICS then return false end

  local phys_obj = ent:GetPhysicsObject()

  if !IsValid(phys_obj) or !phys_obj:IsMoveable() then return false end

  if phys_obj:GetMass() > self:get_mass_limit(actor, ent) then
    return false
  end
end

--- Denies dragging the ragdoll of a player who is getting up, as the Ragdoll plugin would
-- remove the ragdoll in the middle of the drag.
-- @param actor [Player]
-- @param ragdoll [Entity]
-- @param target [Player the player whose ragdoll it is, nil if it belongs to nobody]
-- @return [Boolean false to deny the dragging, nil otherwise]
function PickupObjects:PlayerCanDragRagdoll(actor, ragdoll, target)
  if IsValid(target) and target:is_doing_action('getup') then
    return false
  end
end

--- Blocks physics damage to a ragdoll that is being dragged or was let go of less than a
-- second ago, and to the player it belongs to, so that being dragged over the ground does
-- not hurt them.
-- @param ent [Entity the damaged entity]
-- @param damage_info [CTakeDamageInfo]
-- @return [Boolean true to block the damage, nil otherwise]
function PickupObjects:EntityTakeDamage(ent, damage_info)
  if !damage_info:IsDamageType(DMG_CRUSH) then return end

  local ragdoll = ent

  if ent:IsPlayer() then
    ragdoll = ent.get_ragdoll_entity and ent:get_ragdoll_entity()
  end

  if IsValid(ragdoll) and ragdoll:IsRagdoll() and self:is_drag_protected(ragdoll) then
    return true
  end
end

--- Drops what a player holds when they disconnect.
-- @param actor [Player]
function PickupObjects:PlayerDisconnected(actor)
  self:drop_entity(actor, true)
end
