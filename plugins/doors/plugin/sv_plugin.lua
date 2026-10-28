--- Server side of the Doors plugin: saves and loads the properties, conditions and ownership
-- of doors, locks doors and tells players what they may know about the ownership of a door.

local IsValid = IsValid
local pairs = pairs

Cable.check_networked_string('fl_door_info')

--- Checks whether a player is close enough to a door to use its menu, lock it, trade it,
-- manage it or edit it: within `Doors.use_distance` of it.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Boolean]
function Doors:is_in_reach(actor, entity)
  local reach = self.use_distance

  return actor:GetPos():DistToSqr(entity:GetPos()) <= reach * reach
end

--- Writes the registered properties, the conditions and the ownership of every door on the
-- map to the plugin data storage.
function Doors:save()
  local doors = {}

  for _, entity in ents.Iterator() do
    if entity:is_door() then
      local save_table = {
        id = entity:MapCreationID()
      }

      for property_id, property in pairs(self.properties) do
        if property.get_save_data then
          save_table[property_id] = property.get_save_data(entity)
        end
      end

      if entity.conditions then
        save_table.conditions = entity.conditions
      end

      save_table.ownership = self:get_ownership_data(entity)

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

    for _, door_data in pairs(doors) do
      local door = ents.GetMapCreatedEntity(door_data.id)

      if IsValid(door) then
        for property_id, property in pairs(self.properties) do
          if property.on_load then
            property.on_load(door, door_data[property_id])
          end
        end

        door.conditions = door_data.conditions

        self:set_ownership_data(door, door_data.ownership)

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
  return math.max(tonumber(Config.get(lock ? 'door_lock_time' : 'door_unlock_time')) or 0, 0)
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
      entity:Fire(lock ? 'Close' : 'Open')
    end

    return true
  end

  return actor:start_timed_action(lock ? 'lock_door' : 'unlock_door', duration, {
    text = lock ? 'ui.hud.bar_text.lock_door' : 'ui.hud.bar_text.unlock_door',
    condition = Flux.TimedAction:looking_at(entity, self.use_distance),
    callback = function(target, success)
      if !success or !IsValid(entity) or !hook.Run('PlayerCanLockDoor', target, entity) then return end

      Doors:lock_door(entity, lock)

      if move then
        entity:Fire(lock ? 'Close' : 'Open')
      end
    end
  })
end

--- Collects what a player is told about the ownership of a door when they open its menu.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Map ownable (Boolean), owned (Boolean), level (Number access level of the
--   player), price (Number) and currency (String, may be nil) of the door, group_size
--   (Number of doors in its group); owner_name (String) for those who manage the door and
--   for staff; text (String) and access (List of Maps with id, name and level, sorted by
--   name) for those who manage the door; refund (Number) and refund_currency (String, may
--   be nil) for the owner]
function Doors:get_menu_info(actor, entity)
  local root = self:get_root(entity)
  local state = self:get_state(root)
  local owner = state.owner
  local level = self:get_access_level(actor, root)
  local price, currency = self:get_price(root)
  local info = {
    ownable = state.ownable or false,
    owned = owner != nil,
    level = level,
    price = price,
    currency = currency,
    group_size = #self:get_group(root)
  }

  if owner and (level >= DOOR_ACCESS_MANAGE or actor:can('manage_doors')) then
    info.owner_name = owner.name
  end

  if level >= DOOR_ACCESS_MANAGE then
    local access = {}

    for character_id, entry in pairs(state.access or {}) do
      table.insert(access, { id = character_id, name = entry.name, level = entry.level })
    end

    table.sort(access, function(a, b)
      if a.name == b.name then
        return a.id < b.id
      end

      return a.name < b.name
    end)

    info.text = state.text or ''
    info.access = access
  end

  if level >= DOOR_ACCESS_OWNER then
    info.refund, info.refund_currency = self:get_refund(root)
  end

  return info
end

--- Sends a player what `Doors:get_menu_info` returns for a door, so that their door
-- management menu shows the current state.
-- @param actor [Player]
-- @param entity [Entity the door]
function Doors:send_info(actor, entity)
  if !IsValid(actor) then return end

  Cable.send(actor, 'fl_door_info', entity, self:get_menu_info(actor, entity))
end
