--- Pickup Objects lets players carry light physics objects in their hands, throw them and
-- drag ragdolls along the ground.
-- With the fists out, secondary attack picks up the entity the player is looking at, if it is
-- within two meters and no heavier than the mass limit of the player. While something is
-- held, secondary attack or reload lets go of it and primary attack throws it. With the
-- `pickup_drag_ragdolls` config turned on a ragdoll is not carried: whatever it weighs, it is
-- dragged by the limb the player has grabbed, for as long as they stay on foot with their
-- fists out. That includes the fallen players and the corpses of the Ragdoll plugin. A
-- ragdoll is grabbed as soon as the key is pressed, and the fists do not punch it. A player
-- whose ragdoll is being dragged takes no physics damage through the ragdoll and has the
-- `dragged` networked variable set to true; the Ragdoll plugin asks `Player:get_dragger` to
-- keep them from getting up in the meantime.
--
-- The plugin defines three config keys on the server: `pickup_max_mass` (25) is the heaviest
-- object a player can carry, `pickup_throw_force` (1000) is the force of a throw, where 0
-- turns throwing off, and `pickup_drag_ragdolls` (false) turns the dragging of ragdolls on.
-- They are static: being defined by a server-only file they have no entry in the config
-- menu, so their values are set in the .yml file of the schema.
--
-- Plugins take part through the `PlayerPickupObject`, `PlayerDropObject`,
-- `PlayerThrowObject`, `PlayerCanDragRagdoll` and `AdjustPickupMassLimit` hooks. What is held
-- and by whom is answered by `Player:get_holding_entity`, `Entity:get_holder` and
-- `Player:get_dragger`, and the functions of the `PickupObjects` global make a player pick
-- up, drop or throw an entity.

PLUGIN:set_name('Pickup Objects')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Allows players to pick up, throw and drag objects.')
PLUGIN:set_global('PickupObjects')

if !Config.find('pickup_max_mass') then
  Config.read({
    configs = {
      pickup_max_mass = {
        type = 'number',
        static = true,
        min_value = 0,
        max_value = 1000,
        default_value = 25
      },
      pickup_throw_force = {
        type = 'number',
        static = true,
        min_value = 0,
        max_value = 10000,
        default_value = 1000
      },
      pickup_drag_ragdolls = {
        type = 'boolean',
        static = true,
        default_value = false
      }
    }
  })
end

PLUGIN.holds = PickupObjects.holds or {}

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
local holds = PLUGIN.holds
local player_meta = FindMetaTable('Player')
local ent_meta = FindMetaTable('Entity')

--- Checks whether an entity is dragged rather than carried when it is picked up: a ragdoll,
-- with the pickup_drag_ragdolls config turned on.
-- @param ent [Entity]
-- @return [Boolean]
local function should_drag(ent)
  if ent:IsRagdoll() and Config.get('pickup_drag_ragdolls') then
    return true
  end

  return false
end

--- Checks whether a player has their fists out.
-- @param actor [Player]
-- @return [Boolean]
local function has_fists(actor)
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
local function aims_at_draggable(actor)
  local ent = actor:GetEyeTraceNoCursor().Entity

  return IsValid(ent) and should_drag(ent)
end

--- Checks whether a ragdoll is safe from physics damage: it is being dragged, or was let go
-- of less than a second ago.
-- @param ragdoll [Entity]
-- @return [Boolean]
local function is_drag_protected(ragdoll)
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
local function update_hold(actor, data, cur_time)
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

--- Returns the entity the player is carrying or dragging with their hands.
-- Serverside only.
-- @return [Entity the held entity, or nil if the player holds nothing]
function player_meta:get_holding_entity()
  local data = holds[self]

  if data and IsValid(data.entity) then
    return data.entity
  end
end

--- Returns the player who is dragging the ragdoll of this player.
-- Serverside only. A ragdoll that is carried like any other object, with the
-- pickup_drag_ragdolls config turned off, does not count.
-- @return [Player the dragging player; nil if the player has no ragdoll, nobody drags it or
--   the Ragdoll plugin is not loaded]
function player_meta:get_dragger()
  if !self.get_ragdoll_entity then return end

  local ragdoll = self:get_ragdoll_entity()

  if !IsValid(ragdoll) then return end

  local holder = ragdoll:get_holder()

  if holder and holds[holder].drag then
    return holder
  end
end

--- Returns the player who is carrying or dragging this entity with their hands.
-- Serverside only. Entities held with the physics gun or the gravity gun have no holder.
-- @return [Player the holder, or nil if nobody holds the entity]
function ent_meta:get_holder()
  local holder = self.pickup_holder
  local data = holder and holds[holder]

  if data and data.entity == self and IsValid(holder) then
    return holder
  end
end

--- Returns the heaviest object a player can carry: the pickup_max_mass config, after the
-- AdjustPickupMassLimit hook.
-- @param actor [Player]
-- @param ent=nil [Entity the object the player is trying to pick up]
-- @return [Number mass limit]
function PLUGIN:get_mass_limit(actor, ent)
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
function PLUGIN:force_pickup(actor, ent, bone)
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
function PLUGIN:pickup_entity(actor, ent, bone)
  if !IsValid(actor) or !IsValid(ent) then return false end
  if holds[actor] or !actor:Alive() or actor:InVehicle() then return false end
  if actor.is_ragdolled and actor:is_ragdolled() then return false end
  if ent:IsPlayerHolding() or ent:get_holder() then return false end

  local drag = should_drag(ent)

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
function PLUGIN:drop_entity(actor, forced)
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
function PLUGIN:throw_entity(actor)
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
function PLUGIN:pickup_at_trace(actor)
  if !IsValid(actor) then return end

  if holds[actor] then
    self:drop_entity(actor)

    return false
  end

  local trace = actor:GetEyeTraceNoCursor()
  local ent = trace.Entity

  if !IsValid(ent) then return false end

  if should_drag(ent) then
    if trace.HitPos:DistToSqr(actor:GetShootPos()) > drag_reach then return false end
  elseif ent:GetPos():DistToSqr(actor:GetPos()) > max_dist then
    return false
  end

  return self:pickup_entity(actor, ent, trace.PhysicsBone)
end

--- Picks up an object to carry when secondary attack is released while holding fists and
-- nothing else, and drops the held object when reload is released. Ragdolls that are
-- dragged are left to the StartCommand handler, which grabs them as the key is pressed.
-- @param actor [Player]
-- @param key [Number IN_ enum of the released key]
function PLUGIN:KeyRelease(actor, key)
  if key == IN_ATTACK2 and !holds[actor] then
    if has_fists(actor) and !aims_at_draggable(actor) then
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
function PLUGIN:StartCommand(actor, user_cmd)
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
    if !attack2_pressed or !has_fists(actor) or !aims_at_draggable(actor) then return end
    if !self:pickup_at_trace(actor) or !holds[actor] then return end
  end

  user_cmd:RemoveKey(IN_ATTACK)
  user_cmd:RemoveKey(IN_ATTACK2)
end

--- Updates every hold on each tick, and drops what can no longer be held.
function PLUGIN:Think()
  if next(holds) == nil then return end

  local cur_time = CurTime()
  local lost

  for actor, data in pairs(holds) do
    if !update_hold(actor, data, cur_time) then
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
function PLUGIN:PlayerPickupObject(actor, ent, drag)
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
function PLUGIN:PlayerCanDragRagdoll(actor, ragdoll, target)
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
function PLUGIN:EntityTakeDamage(ent, damage_info)
  if !damage_info:IsDamageType(DMG_CRUSH) then return end

  local ragdoll = ent

  if ent:IsPlayer() then
    ragdoll = ent.get_ragdoll_entity and ent:get_ragdoll_entity()
  end

  if IsValid(ragdoll) and ragdoll:IsRagdoll() and is_drag_protected(ragdoll) then
    return true
  end
end

--- Drops what a player holds when they disconnect.
-- @param actor [Player]
function PLUGIN:PlayerDisconnected(actor)
  self:drop_entity(actor, true)
end
