--- Server-side hooks of the Doors plugin: opens the door menu, toggles the lock of a door that
-- is used while sprinting and checks the conditions of doors.

--- Opens the door menu for the player if they are looking at a door
-- that is closer than 115 units.
-- @param actor [Player]
function Doors:ShowSpare1(actor)
  local trace = actor:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if IsValid(entity) and entity:is_door() and actor:GetPos():Distance(entity:GetPos()) < 115 then
    --- Asks whether a player may lock and unlock a door. Called on the server when the player
    -- opens the menu of the door, when they use the door and when they ask to lock or unlock
    -- it from the menu.
    -- @param actor [Player]
    -- @param entity [Entity the door]
    -- @return [Boolean return true to allow it; the player may not lock the door when nothing
    --   is returned]
    local can_lock = hook.Run('PlayerCanLockDoor', actor, entity) or false

    Cable.send(actor, 'fl_door_menu', entity, can_lock, entity.conditions)
  end
end

--- Throttles the use of doors and toggles the lock of a door when a player who is
-- allowed to lock it uses it while sprinting. Runs the PlayerUseDoor hook for every
-- use of a door that is not blocked.
-- @param activator [Player]
-- @param entity [Entity the entity that is being used]
-- @return [Boolean false if the door is on cooldown or has just been locked,
--   nil otherwise]
function Doors:PlayerUse(activator, entity)
  local cur_time = CurTime()

  if IsValid(entity) and entity:is_door() and activator:GetPos():Distance(entity:GetPos()) < 115 then
    if !entity.next_use or entity.next_use <= cur_time then
      if hook.Run('PlayerCanLockDoor', activator, entity) and activator:IsSprinting() then
        local locked = entity:get_nv('fl_locked')

        self:lock_door(entity, !locked)
        entity:Fire(locked and 'Open' or 'Close')

        entity.next_use = cur_time + 2

        if !locked then
          return false
        end
      end

      entity.next_use = cur_time + 0.5

      --- Called on the server when a player uses a door that is within reach and not on its
      -- use cooldown, except for the use that has just locked the door.
      -- @param activator [Player]
      -- @param entity [Entity the door]
      hook.Run('PlayerUseDoor', activator, entity)
    else
      return false
    end
  end
end

--- Allows the player to lock and unlock the door if they satisfy its conditions.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Boolean true if the player passes the door's conditions, nil otherwise]
function Doors:PlayerCanLockDoor(actor, entity)
  local conditions = entity.conditions

  if conditions and Conditions:check(actor, conditions) then
    return true
  end
end
