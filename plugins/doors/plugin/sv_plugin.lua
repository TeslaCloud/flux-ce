--- Server side of the Doors plugin: saves and loads the properties, conditions and ownership
-- of doors, locks doors and applies what the door menu sends.

--- Loads the saved doors when the framework loads its data.
function Doors:LoadData()
  self:load()
end

--- Saves the doors when the framework saves its data.
function Doors:SaveData()
  self:save()
end

--- Writes the registered properties, the conditions and the ownership of every door on the
-- map to the plugin data storage.
function Doors:save()
  local doors = {}

  for k, v in ents.Iterator() do
    if v:is_door() then
      local save_table = {
        id = v:MapCreationID()
      }

      for k1, v1 in pairs(self.properties) do
        if v1.get_save_data then
          save_table[k1] = v1.get_save_data(v)
        end
      end

      if v.conditions then
        save_table.conditions = v.conditions
      end

      save_table.ownership = self:get_ownership_data(v)

      table.insert(doors, save_table)
    end
  end

  Data.save_plugin('doors', doors)
end

--- Applies the saved properties, conditions and ownership to the doors of the map, skipping
-- the saved doors that the map no longer has. Runs the InitialDoorsLoad hook instead if
-- nothing has been saved yet.
function Doors:load()
  local doors = Data.load_plugin('doors', {})

  if doors and #doors > 0 then
    local loaded = {}

    for k, v in pairs(doors) do
      local door = ents.GetMapCreatedEntity(v.id)

      if IsValid(door) then
        for k1, v1 in pairs(self.properties) do
          if v1.on_load then
            v1.on_load(door, v[k1])
          end
        end

        door.conditions = v.conditions

        self:set_ownership_data(door, v.ownership)

        table.insert(loaded, door)
      end
    end

    self:restore_links(loaded)
  else
    --- Called on the server when the doors are loaded and no door data has been saved for the
    -- map yet. Lets a schema set the doors of the map up for the first time.
    hook.Run('InitialDoorsLoad')
  end
end

--- Locks or unlocks the door and plays the latch sound.
-- @param entity [Entity the door]
-- @param lock [Boolean true to lock, false to unlock]
function Doors:lock_door(entity, lock)
  Doors.properties['locked'].on_load(entity, lock)

  entity:EmitSound('doors/door_latch1.wav', 60)
end

--- Returns how long it takes a player to lock or to unlock a door.
-- @param lock [Boolean true for locking, false for unlocking]
-- @return [Number seconds from the door_lock_time or the door_unlock_time config; 0 means
--   that it happens at once]
function Doors:get_lock_time(lock)
  return math.max(tonumber(Config.get(lock and 'door_lock_time' or 'door_unlock_time')) or 0, 0)
end

--- Makes a player lock or unlock a door. It happens at once unless the door_lock_time or the
-- door_unlock_time config is above 0: then the player starts a timed action ('lock_door' or
-- 'unlock_door') that lasts as long as they keep looking at the door from nearby, and the
-- door is locked or unlocked when it completes, provided that the player still passes
-- PlayerCanLockDoor. Whether the player may lock the door at all is up to the caller.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @param lock [Boolean true to lock, false to unlock]
-- @param move=false [Boolean also close the door when it is locked and open it when it is
--   unlocked]
-- @return [Boolean true if the door has been locked or unlocked or the timed action has
--   started, false if the player is busy with something else]
function Doors:player_lock_door(actor, entity, lock, move)
  local duration = self:get_lock_time(lock)

  if duration <= 0 then
    self:lock_door(entity, lock)

    if move then
      entity:Fire(lock and 'Close' or 'Open')
    end

    return true
  end

  return actor:start_timed_action(lock and 'lock_door' or 'unlock_door', duration, {
    text = lock and 'ui.hud.bar_text.lock_door' or 'ui.hud.bar_text.unlock_door',
    condition = Flux.TimedAction:looking_at(entity, 160),
    callback = function(target, success)
      if !success or !IsValid(entity) or !hook.Run('PlayerCanLockDoor', target, entity) then return end

      Doors:lock_door(entity, lock)

      if move then
        entity:Fire(lock and 'Close' or 'Open')
      end
    end
  })
end

Cable.receive('fl_send_door_data', function(actor, entity, id, data)
  if actor:can('manage_doors') and IsValid(entity) and entity:is_door()
  and actor:GetPos():Distance(entity:GetPos()) < 115 then
    local property = Doors.properties[id]

    if property and property.on_load then
      property.on_load(entity, data)
    end
  end
end)

Cable.receive('fl_lock_door', function(actor, entity, lock)
  if IsValid(entity) and entity:is_door() and hook.Run('PlayerCanLockDoor', actor, entity) then
    if !Doors:player_lock_door(actor, entity, tobool(lock)) then
      actor:notify('error.cant_now')
    end
  end
end)

Cable.receive('fl_send_door_conditions', function(actor, entity, conditions)
  if actor:can('manage_doors') and IsValid(entity) and entity:is_door() and conditions and istable(conditions)
  and actor:GetPos():Distance(entity:GetPos()) < 115 then
    entity.conditions = conditions
  end
end)
