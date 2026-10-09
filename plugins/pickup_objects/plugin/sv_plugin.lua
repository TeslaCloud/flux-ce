--- Server side of the Pickup Objects plugin: the holds, the functions that make a player
-- pick up, drop or throw an entity, and the checks the hooks of the plugin are built on.
-- A hold is kept in `PickupObjects.holds` under the holding player, as a table with the
-- entity, collision_group, drag, bone, mass, target and check_time fields.

PickupObjects.holds = PickupObjects.holds or {}

local max_dist = Unit:meters(2) ^ 2
local drag_reach = 96 ^ 2
local drag_break_dist = 128 ^ 2
local drag_forward = 16
local drag_height = 32
local drag_gain = 15
local drag_max_speed = 400
local drag_bone_mass = 50
local pickup_cooldown = 1
local drop_protection = 1
local holds = PickupObjects.holds

--- Checks whether an entity is dragged rather than carried when it is picked up: a ragdoll,
-- with the pickup_drag_ragdolls config turned on.
-- @param ent [Entity]
-- @return [Boolean]
function PickupObjects:should_drag(ent)
  if ent:IsRagdoll() and Config.get('pickup_drag_ragdolls') then
    return true
  end

  return false
end

--- Checks whether a player has their fists out.
-- @param actor [Player]
-- @return [Boolean]
function PickupObjects:has_fists(actor)
  local weapon = actor:GetActiveWeapon()

  if IsValid(weapon) and weapon:GetClass():include('fists') then
    return true
  end

  return false
end

--- Checks whether the entity a player is looking at is one that is dragged rather than
-- carried.
-- @param actor [Player]
-- @return [Boolean]
function PickupObjects:aims_at_draggable(actor)
  local ent = actor:GetEyeTraceNoCursor().Entity

  return IsValid(ent) and self:should_drag(ent)
end

--- Checks whether a ragdoll is safe from physics damage: it is being dragged, or was let go
-- of less than a second ago.
-- @param ragdoll [Entity]
-- @return [Boolean]
function PickupObjects:is_drag_protected(ragdoll)
  local holder = ragdoll:get_holder()

  if holder and holds[holder].drag then
    return true
  end

  return ragdoll.pickup_dropped_at != nil and ragdoll.pickup_dropped_at + drop_protection > CurTime()
end

--- Ends a hold without asking anyone: forgets it, makes the engine let go of a carried
-- object, gives a dragged limb its mass back, restores the collision group of the entity
-- and starts the pickup cooldown of the player. The attack keys of the player stay out of
-- their commands until both are let go of, so that a key that is still down when the hold
-- ends does not reach the fists.
-- @param actor [Player the holder; may no longer be valid]
-- @param data [Map the hold, as kept in PickupObjects.holds]
local function release(actor, data)
  local ent = data.entity

  holds[actor] = nil

  if IsValid(data.target) then
    data.target:set_nv('dragged', false)
  end

  if IsValid(ent) then
    ent.pickup_holder = nil

    if data.drag then
      local phys_obj = ent:GetPhysicsObjectNum(data.bone)

      if IsValid(phys_obj) then
        phys_obj:SetMass(data.mass)
      end

      ent.pickup_dropped_at = CurTime()
    elseif IsValid(actor) and ent:IsPlayerHolding() then
      actor:DropObject()
    end

    ent:SetCollisionGroup(data.collision_group)
  end

  if IsValid(actor) then
    actor.holding_object = nil
    actor.next_pickup = CurTime() + pickup_cooldown
    actor.pickup_keys_blocked = true
  end
end

--- Keeps a hold going for one tick. A carried object only has to be still held by the
-- engine. A dragged ragdoll is pulled by its grabbed limb towards a point in front of the
-- player, below their eyes, and the fists of the player are kept from punching until the
-- pickup cooldown that follows the drag is over.
-- @param actor [Player the holder]
-- @param data [Map the hold, as kept in PickupObjects.holds]
-- @param cur_time [Number CurTime() of the tick]
-- @return [Boolean false if the hold is over: the player or the entity is gone, the engine
--   has let go of the object, or the player can no longer drag the ragdoll or has moved too
--   far away from it]
function PickupObjects:update_hold(actor, data, cur_time)
  local ent = data.entity

  if !IsValid(actor) or !IsValid(ent) then return false end

  if !data.drag then
    return cur_time < data.check_time or ent:IsPlayerHolding()
  end

  if !actor:Alive() or actor:InVehicle() or actor:GetMoveType() != MOVETYPE_WALK then return false end
  if actor.is_ragdolled and actor:is_ragdolled() then return false end

  local weapon = actor:GetActiveWeapon()

  if !IsValid(weapon) or !weapon:GetClass():include('fists') then return false end

  local phys_obj = ent:GetPhysicsObjectNum(data.bone)

  if !IsValid(phys_obj) or !phys_obj:IsMoveable() then return false end

  local shoot_pos = actor:GetShootPos()
  local goal = shoot_pos + Angle(0, actor:EyeAngles().y, 0):Forward() * drag_forward

  goal.z = shoot_pos.z - drag_height

  local offset = goal - phys_obj:GetPos()

  if offset:LengthSqr() > drag_break_dist then return false end

  local velocity = offset * drag_gain
  local speed = velocity:Length()

  if speed > drag_max_speed then
    velocity = velocity * (drag_max_speed / speed)
  end

  if IsValid(data.target) and data.target:get_ragdoll_entity() != ent then
    data.target:set_nv('dragged', false)
    data.target = nil
  end

  weapon:SetNextPrimaryFire(cur_time + pickup_cooldown)
  weapon:SetNextSecondaryFire(cur_time + pickup_cooldown)

  phys_obj:Wake()
  phys_obj:SetVelocity(velocity)

  return true
end

--- Returns the heaviest object a player can carry: the pickup_max_mass config, after the
-- AdjustPickupMassLimit hook.
-- @param actor [Player]
-- @param ent=nil [Entity the object the player is trying to pick up]
-- @return [Number mass limit]
function PickupObjects:get_mass_limit(actor, ent)
  local info = { limit = tonumber(Config.get('pickup_max_mass')) or 25 }

  --- Lets plugins change the heaviest object a player can carry, for example with the
  -- strength of their character. Called on the server when the plugin's own
  -- PlayerPickupObject handler compares the mass of an object with the limit, and by
  -- `PickupObjects:get_mass_limit`. Every handler may change the table, so a handler should
  -- return nothing to let the others run. Dragged ragdolls have no mass limit.
  -- @param actor [Player the player picking the object up]
  -- @param ent [Entity the object, nil if the limit is asked for no object in particular]
  -- @param info [Map modified in place: limit (Number the mass limit, the pickup_max_mass
  --   config to begin with)]
  hook.Run('AdjustPickupMassLimit', actor, ent, info)

  return tonumber(info.limit) or 0
end

--- Makes a player hold an entity without asking any hook. What the player held before is
-- dropped, and so is the entity by the player who held it.
-- A carried object is handed to the engine and does not collide with players while it is
-- held. A dragged entity follows the player by the given physics object, which is made
-- heavy enough to pull the rest along; the drag ends by itself once the player dies, leaves
-- their feet, puts the fists away or gets too far from the entity.
-- @param actor [Player]
-- @param ent [Entity]
-- @param bone=nil [Number index of the physics object to drag the entity by, as in the
--   PhysicsBone field of a trace; nil carries the entity instead]
-- @return [Boolean true if the player holds the entity now, false if the player or the
--   entity is not valid or the entity has no movable physics object to hold it by]
function PickupObjects:force_pickup(actor, ent, bone)
  if !IsValid(actor) or !IsValid(ent) then return false end

  local phys_obj

  if bone then
    phys_obj = ent:GetPhysicsObjectNum(bone)
  else
    phys_obj = ent:GetPhysicsObject()
  end

  if !IsValid(phys_obj) or !phys_obj:IsMoveable() then return false end

  self:drop_entity(actor, true)

  local holder = ent:get_holder()

  if holder then
    self:drop_entity(holder, true)
  end

  if !IsValid(ent) or !IsValid(phys_obj) then return false end

  local data = {
    entity = ent,
    collision_group = ent:GetCollisionGroup()
  }

  if bone then
    local weapon = actor:GetActiveWeapon()

    data.drag = true
    data.bone = bone
    data.mass = phys_obj:GetMass()
    data.target = ent.get_ragdoll_owner and ent:get_ragdoll_owner()

    phys_obj:SetMass(math.max(data.mass, drag_bone_mass))
    phys_obj:Wake()
    ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    if IsValid(data.target) then
      data.target:set_nv('dragged', true)
    end

    if IsValid(weapon) and isfunction(weapon.SetNextMeleeAttack) then
      weapon:SetNextMeleeAttack(0)
    end
  else
    data.check_time = CurTime() + 0.1

    ent:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
    actor:PickupObject(ent)
    actor.holding_object = ent
  end

  ent.pickup_holder = actor
  holds[actor] = data
  actor.next_pickup = CurTime() + pickup_cooldown

  return true
end

--- Makes a player pick up an entity if they are able to and the hooks allow it.
-- The player must be alive, on foot, not ragdolled and hold nothing, and nobody may hold
-- the entity. A ragdoll is dragged if the pickup_drag_ragdolls config is on, which the
-- PlayerCanDragRagdoll hook can veto; everything else is carried. The PlayerPickupObject
-- hook can veto both. The distance to the entity is not checked.
-- @param actor [Player]
-- @param ent [Entity]
-- @param bone=0 [Number index of the physics object to drag a ragdoll by; not used for
--   entities that are carried]
-- @return [Boolean true if the entity was picked up, false otherwise]
function PickupObjects:pickup_entity(actor, ent, bone)
  if !IsValid(actor) or !IsValid(ent) then return false end
  if holds[actor] or !actor:Alive() or actor:InVehicle() then return false end
  if actor.is_ragdolled and actor:is_ragdolled() then return false end
  if ent:IsPlayerHolding() or ent:get_holder() then return false end

  local drag = self:should_drag(ent)

  if drag then
    local owner = ent.get_ragdoll_owner and ent:get_ragdoll_owner()

    --- Asks whether a player may start dragging a ragdoll.
    -- Called on the server when the player tries to pick up a ragdoll within reach while the
    -- pickup_drag_ragdolls config is on, before PlayerPickupObject. The plugin's own handler
    -- denies it while the player the ragdoll belongs to is getting up.
    -- @param actor [Player The player who is about to drag the ragdoll]
    -- @param ragdoll [Entity The ragdoll]
    -- @param target [Player The player whose ragdoll it is, fallen over or dead; nil for a
    --   corpse left behind by a player who has respawned and for any other ragdoll]
    -- @return [Boolean Return false to prevent the dragging]
    if hook.Run('PlayerCanDragRagdoll', actor, ent, owner) == false then return false end
  end

  --- Asks whether a player may pick up an object with their hands.
  -- Called on the server when the player tries to pick up the entity they are looking at
  -- and it is close enough. The plugin's own handler denies pickups during the cooldown of
  -- the player and, for objects that are carried, anything that is not a movable physics
  -- object or weighs more than the mass limit of the player (see AdjustPickupMassLimit).
  -- A handler that returns true lets the player pick up what the plugin would deny.
  -- @param actor [Player The player picking the object up]
  -- @param ent [Entity The object being picked up]
  -- @param drag [Boolean True if the object is a ragdoll that is going to be dragged, false if
  --   it is going to be carried]
  -- @return [Boolean Return false to prevent the pickup]
  if hook.Run('PlayerPickupObject', actor, ent, drag) == false then return false end

  return self:force_pickup(actor, ent, drag and (bone or 0) or nil)
end

--- Makes a player let go of the entity they hold.
-- The PlayerDropObject hook can veto a drop that is not forced.
-- @param actor [Player the holder; may no longer be valid for a forced drop]
-- @param forced=false [Boolean drop the entity whatever the hook returns]
-- @return [Boolean true if the player has let go of an entity, false if they held nothing
--   or the drop was vetoed]
function PickupObjects:drop_entity(actor, forced)
  local data = holds[actor]

  if !data then return false end

  if IsValid(data.entity) then
    --- Called on the server when a player drops the object they carry or drag.
    -- It is run once per drop: before a drop or a throw the player asks for, which a handler
    -- can prevent, or once the object is found to be no longer held for any other reason;
    -- what handlers return is ignored then.
    -- @param actor [Player The player holding the object; may no longer be valid if they
    --   have disconnected]
    -- @param ent [Entity The object being dropped]
    -- @return [Boolean Return false to keep the player from dropping the object]
    if hook.Run('PlayerDropObject', actor, data.entity) == false and !forced then return false end
  end

  release(actor, data)

  return true
end

--- Makes a player throw the entity they hold in the direction they are looking.
-- The PlayerThrowObject hook can veto the throw and change its force, and the
-- PlayerDropObject hook can veto it as well. The force is scaled with the mass of the entity
-- the way the engine does it for objects carried with the use key, by 0.5 for half a
-- kilogram and less up to 4 for 15 kilograms and more, and is spread over the physics
-- objects of the entity.
-- @param actor [Player]
-- @return [Boolean true if the player has let go of the entity, false if they hold nothing,
--   the throw was vetoed or its force is not positive]
function PickupObjects:throw_entity(actor)
  local data = holds[actor]

  if !data or !IsValid(actor) or !IsValid(data.entity) then return false end

  local ent = data.entity
  local info = {
    force = tonumber(Config.get('pickup_throw_force')) or 1000,
    direction = actor:GetAimVector()
  }

  --- Asks whether a player may throw the object they hold, and lets plugins change the
  -- throw. Called on the server when the player presses primary attack while holding an
  -- object, before PlayerDropObject. Nothing happens if the throw is prevented or its force
  -- is not positive: the player keeps holding the object.
  -- @param actor [Player The player throwing the object]
  -- @param ent [Entity The object being thrown]
  -- @param info [Map Modified in place: force (Number the pickup_throw_force config to
  --   begin with, before it is scaled with the mass of the object) and direction (Vector the
  --   aim vector of the player)]
  -- @return [Boolean Return false to prevent the throw]
  if hook.Run('PlayerThrowObject', actor, ent, info) == false then return false end

  local force = tonumber(info.force) or 0

  if force <= 0 or !isvector(info.direction) then return false end
  if !self:drop_entity(actor) then return false end
  if !IsValid(ent) then return true end

  local parts, total_mass = {}, 0

  for i = 0, ent:GetPhysicsObjectCount() - 1 do
    local phys_obj = ent:GetPhysicsObjectNum(i)

    if IsValid(phys_obj) then
      table.insert(parts, phys_obj)

      total_mass = total_mass + phys_obj:GetMass()
    end
  end

  if total_mass <= 0 then return true end

  local mass_factor = math.Remap(math.Clamp(total_mass, 0.5, 15), 0.5, 15, 0.5, 4)
  local velocity = info.direction:GetNormalized() * (force * mass_factor / total_mass)

  for k, v in ipairs(parts) do
    v:Wake()
    v:ApplyForceCenter(velocity * v:GetMass())
  end

  return true
end

--- Drops the entity the player is holding, or else picks up the entity they are looking at.
-- An object to carry must be within 2 meters; a ragdoll to drag must be hit by the eye
-- trace within 96 units. See `PickupObjects:pickup_entity` for the other conditions and the
-- hooks that can veto the pickup, and `PickupObjects:drop_entity` for the drop.
-- @param actor [Player]
-- @return [Boolean true if an object was picked up, false otherwise; nil if the player
--   is not valid]
function PickupObjects:pickup_at_trace(actor)
  if !IsValid(actor) then return end

  if holds[actor] then
    self:drop_entity(actor)

    return false
  end

  local trace = actor:GetEyeTraceNoCursor()
  local ent = trace.Entity

  if !IsValid(ent) then return false end

  if self:should_drag(ent) then
    if trace.HitPos:DistToSqr(actor:GetShootPos()) > drag_reach then return false end
  elseif ent:GetPos():DistToSqr(actor:GetPos()) > max_dist then
    return false
  end

  return self:pickup_entity(actor, ent, trace.PhysicsBone)
end
