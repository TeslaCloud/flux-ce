--- Server-side hooks of the Doors plugin: opens the door menu, toggles the lock of a door that
-- is used while sprinting, checks the conditions and the access lists of doors and releases
-- the doors of deleted characters.

--- Opens the door menu for the player if they are looking at a door within
-- `Doors.use_distance`. Along with the conditions of the door the client is sent what the
-- player may know about its ownership (see `Doors:get_menu_info`).
-- @param actor [Player]
function Doors:ShowSpare1(actor)
  local trace = actor:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if IsValid(entity) and entity:is_door() and self:is_in_reach(actor, entity) then
    --- Asks whether a player may lock and unlock a door. Called on the server when the player
    -- opens the menu of the door, when they use the door, when they ask to lock or unlock it
    -- from the menu and when a timed locking or unlocking of theirs completes. The Doors
    -- plugin itself allows it to those who pass the conditions of the door and to the
    -- characters that own the door or have access to it.
    -- @param actor [Player]
    -- @param entity [Entity the door]
    -- @return [Boolean return true to allow it; the player may not lock the door when nothing
    --   is returned]
    local can_lock = hook.Run('PlayerCanLockDoor', actor, entity) or false

    Cable.send(actor, 'fl_door_menu', entity, can_lock, entity.conditions, self:get_menu_info(actor, entity))
  end
end

--- Throttles the use of doors and toggles the lock of a door when a player who is
-- allowed to lock it uses it while sprinting. If locking or unlocking takes time (the
-- door_lock_time and door_unlock_time configs), the use starts the timed action instead and
-- is blocked. Runs the PlayerUseDoor hook for every use of a door that is not blocked.
-- @param activator [Player]
-- @param entity [Entity the entity that is being used]
-- @return [Boolean false if the door is on cooldown, has just been locked or is about to
--   be locked or unlocked by a timed action, nil otherwise]
function Doors:PlayerUse(activator, entity)
  local cur_time = CurTime()

  if IsValid(entity) and entity:is_door() and self:is_in_reach(activator, entity) then
    if !entity.next_use or entity.next_use <= cur_time then
      if hook.Run('PlayerCanLockDoor', activator, entity) and activator:IsSprinting() then
        local locked = entity:get_nv('fl_locked')

        if self:get_lock_time(!locked) > 0 then
          entity.next_use = cur_time + 1

          self:player_lock_door(activator, entity, !locked, true)

          return false
        end

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

--- Allows the player to lock and unlock the door if they satisfy its conditions, or if
-- their character owns the door or has been given access to it.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Boolean true if the player passes the door's conditions or has access to the
--   door, nil otherwise]
function Doors:PlayerCanLockDoor(actor, entity)
  local conditions = entity.conditions

  if conditions and Conditions:check(actor, conditions) then
    return true
  end

  if self:has_access(actor, entity) then
    return true
  end
end

--- Releases the doors of a character that is about to be deleted and takes away the access
-- it had to the doors of others.
-- @param actor [Player the player who deletes the character]
-- @param id [Number ID of the character]
-- @param character [Character the character that is about to be deleted]
function Doors:OnCharacterDelete(actor, id, character)
  self:release_character(id)
end
