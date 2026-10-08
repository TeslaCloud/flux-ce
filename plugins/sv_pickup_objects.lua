--- Pickup Objects lets players carry light physics objects in their hands.
-- With the fists out, secondary attack picks up the entity the player is looking at, if it is
-- within two meters and has a mass of 25 or less, or drops the one they hold; reload drops it
-- as well. Plugins can veto both through the `PlayerPickupObject` and `PlayerDropObject`
-- hooks.

PLUGIN:set_name('Pickup Objects')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Allows players to pick up objects.')

local max_dist = Unit:meters(2) ^ 2

--- Drops the object the player is holding, or else picks up the entity they are looking at.
-- The entity must be within 2 meters and not held by anyone. The PlayerPickupObject and
-- PlayerDropObject hooks can veto the pickup and the drop.
-- @param actor [Player]
-- @return [Boolean true if an object was picked up, false otherwise; nil if the player
--   is not valid]
function PLUGIN:pickup_at_trace(actor)
  if !IsValid(actor) then return end

  if IsValid(actor.holding_object) then
    --- Called on the server when a player drops the object they carry.
    -- It is run before a drop the player asks for, which a handler can prevent, and again from
    -- a timer once the object is found to be no longer held, for whatever reason; what
    -- handlers return is ignored then.
    -- @param actor [Player The player carrying the object; may no longer be valid when called
    --   from the timer]
    -- @param ent [Entity The object being dropped]
    -- @return [Boolean Return false to keep the player from dropping the object]
    if hook.Run('PlayerDropObject', actor, actor.holding_object) != false then
      actor:DropObject()
      actor.holding_object = nil
    end

    return false
  end

  local ent = actor:GetEyeTraceNoCursor().Entity

  if IsValid(ent) then
    if ent:IsPlayerHolding() then return false end
    if ent:GetPos():DistToSqr(actor:GetPos()) > max_dist then return false end

    if !actor.holding_object then
      --- Asks whether a player may pick up an object with their hands.
      -- Called on the server when the player tries to pick up the entity they are looking at
      -- and it is close enough. The plugin's own handler denies objects with a mass over 25
      -- and pickups during the cooldown of the player.
      -- @param actor [Player The player picking the object up]
      -- @param ent [Entity The object being picked up]
      -- @return [Boolean Return false to prevent the pickup]
      if hook.Run('PlayerPickupObject', actor, ent) != false then
        actor:PickupObject(ent)
        actor.holding_object = ent

        local timer_name = 'check_ent_hold_'..actor:SteamID()

        timer.Create(timer_name, 0.1, 0, function()
          if !IsValid(actor) then
            if IsValid(ent) then
              hook.Run('PlayerDropObject', actor, ent)
            end

            timer.Remove(timer_name)
            return
          end

          if IsValid(ent) and !ent:IsPlayerHolding() then
            hook.Run('PlayerDropObject', actor, ent)
            actor.holding_object = nil
            timer.Remove(timer_name)
          elseif !IsValid(ent) then
            actor.holding_object = nil
            timer.Remove(timer_name)
          end
        end)

        return true
      end
    end
  end

  return false
end

--- Picks up or drops an object when secondary attack is released while holding fists, and
-- drops the held object when reload is released.
-- @param actor [Player]
-- @param key [Number IN_ enum of the released key]
function PLUGIN:KeyRelease(actor, key)
  if key == IN_ATTACK2 then
    local wep = actor:GetActiveWeapon()

    if IsValid(wep) and wep:GetClass():include('fists') then
      self:pickup_at_trace(actor)
    end
  end

  if key == IN_RELOAD and IsValid(actor.holding_object) then
    self:pickup_at_trace(actor)
  end
end

--- Denies pickups during the player's one second cooldown and of objects with a mass over
-- 25. Otherwise changes the object's collision group and starts the cooldown.
-- @param actor [Player]
-- @param ent [Entity the object being picked up]
-- @return [Boolean false to deny the pickup, nil otherwise]
function PLUGIN:PlayerPickupObject(actor, ent)
  if actor.next_pickup and actor.next_pickup > CurTime() then return false end

  local phys_obj = ent:GetPhysicsObject()

  if phys_obj:GetMass() > 25 then
    return false
  else
    ent:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
  end

  if IsValid(actor) then
    actor.next_pickup = CurTime() + 1
  end
end

--- Restores the dropped object's collision group and starts the player's one second
-- pickup cooldown.
-- @param actor [Player the holder; may no longer be valid if they have disconnected]
-- @param ent [Entity the dropped object]
function PLUGIN:PlayerDropObject(actor, ent)
  ent:SetCollisionGroup(COLLISION_GROUP_NONE)

  if IsValid(actor) then
    actor.next_pickup = CurTime() + 1
  end
end
