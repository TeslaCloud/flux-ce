--- Server side of the Doors plugin: saves and loads the properties, conditions and ownership
-- of doors, locks doors, tells players what they may know about the ownership of a door and
-- applies what the door menu sends.

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
    condition = Flux.TimedAction:looking_at(entity, self.use_distance),
    callback = function(target, success)
      if !success or !IsValid(entity) or !hook.Run('PlayerCanLockDoor', target, entity) then return end

      Doors:lock_door(entity, lock)

      if move then
        entity:Fire(lock and 'Close' or 'Open')
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

    for k, v in pairs(state.access or {}) do
      table.insert(access, { id = k, name = v.name, level = v.level })
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

Cable.receive('fl_send_door_data', function(actor, entity, id, data)
  if actor:can('manage_doors') and IsValid(entity) and entity:is_door() and Doors:is_in_reach(actor, entity) then
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
  if actor:can('manage_doors') and IsValid(entity) and entity:is_door() and istable(conditions)
  and Doors:is_in_reach(actor, entity) then
    entity.conditions = conditions
  end
end)

--- Checks a request that the door menu of a player has sent: the entity has to be a door
-- within `Doors.use_distance` of the living player, and a player may send a request only
-- every 0.3 seconds. The player is told what is wrong.
-- @param actor [Player]
-- @param entity [Any what the client sent as the door]
-- @return [Boolean whether the request may be handled]
local function accept_request(actor, entity)
  if !isentity(entity) or !IsValid(entity) or !entity:is_door() then return false end

  if !actor:Alive() then
    actor:notify('error.cant_now')

    return false
  end

  local cur_time = CurTime()

  if actor.next_door_request and actor.next_door_request > cur_time then
    actor:notify('error.wait')

    return false
  end

  if !Doors:is_in_reach(actor, entity) then
    actor:notify('error.door.too_far')

    return false
  end

  actor.next_door_request = cur_time + 0.3

  return true
end

Cable.receive('fl_door_buy', function(actor, entity)
  if !accept_request(actor, entity) then return end

  local success, reason, arguments = Doors:buy(actor, entity)

  if !success then
    actor:notify(reason, arguments)
  end
end)

Cable.receive('fl_door_sell', function(actor, entity)
  if !accept_request(actor, entity) then return end

  local success, reason, arguments = Doors:sell(actor, entity)

  if !success then
    actor:notify(reason, arguments)
  end
end)

Cable.receive('fl_door_set_text', function(actor, entity, text)
  if !accept_request(actor, entity) then return end

  local success, reason = Doors:change_text(actor, entity, text)

  if success then
    actor:notify('notification.door.text_set')
  else
    actor:notify(reason)
  end

  Doors:send_info(actor, entity)
end)

Cable.receive('fl_door_set_access', function(actor, entity, character_id, level)
  if !accept_request(actor, entity) then return end

  local success, reason, arguments = Doors:change_access(actor, entity, character_id, level)

  if !success then
    actor:notify(reason, arguments)
  end

  Doors:send_info(actor, entity)
end)

Cable.receive('fl_door_evict', function(actor, entity)
  if !actor:can('manage_doors') or !accept_request(actor, entity) then return end

  if Doors:evict(entity) then
    actor:notify('notification.door.evict_done')

    Doors:save()
  else
    actor:notify('error.door.not_owned')
  end
end)
