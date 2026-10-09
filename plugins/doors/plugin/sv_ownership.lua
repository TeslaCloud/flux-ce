--- Door ownership, serverside: which doors can be owned, who owns them and which doors are
-- linked into groups.
-- Every door has an ownership state: whether it is ownable, its price, its owner, the
-- characters with access to it and the text of its owner. The doors of a group share one
-- state, so whatever is done to one of them applies to all; the group is made of a main
-- door and the doors linked to it. `Doors:set_owner` and `Doors:clear_owner` change the
-- owner without asking, for staff tools and other plugins, and leave the saving to the
-- caller; what staff change through `Doors:evict`, `Doors:link` and `Doors:unlink` is saved
-- right away. Buying and selling live in sv_trade, the access lists and the text of the
-- owner in sv_access, and how the state is saved and loaded in sv_persistence.

--- Returns the ownership state of a door, creating it if the door has none yet. The doors
-- of a group share one table. Do not change it directly: use the setters, which also
-- network the change.
-- @param entity [Entity the door]
-- @return [Map the state: ownable (Boolean), price (Number, nil for the default price),
--   owner (Map with the id and name of the character, the paid price and its currency; nil
--   if the door has no owner), access (Map of character IDs to Maps with level and name) and
--   text (String, nil if there is none)]
function Doors:get_state(entity)
  local state = entity.door_state

  if !state then
    state = {}

    entity.door_state = state
  end

  return state
end

--- Returns the main door of the group that a door is linked into.
-- @param entity [Entity the door]
-- @return [Entity the main door, which is the door itself if it is not linked to another]
function Doors:get_root(entity)
  local parent = entity.door_parent

  if IsValid(parent) then
    return parent
  end

  return entity
end

--- Returns every door of the group that a door is linked into.
-- @param entity [Entity the door]
-- @return [List<Entity> the main door followed by the doors linked to it; only the door
--   itself if it is not linked]
function Doors:get_group(entity)
  local root = self:get_root(entity)
  local group = { root }
  local children = root.door_children

  if children then
    for k, v in ipairs(children) do
      if IsValid(v) then
        table.insert(group, v)
      end
    end
  end

  return group
end

--- Networks the ownership state of a door to the clients, for every door of its group: the
-- 'fl_door_ownable', 'fl_door_price', 'fl_door_owner' and 'fl_door_text' variables.
-- @param entity [Entity the door]
function Doors:sync(entity)
  local root = self:get_root(entity)
  local state = self:get_state(root)
  local owner_id = state.owner and state.owner.id or nil

  for k, v in ipairs(self:get_group(root)) do
    v:set_nv('fl_door_ownable', state.ownable and true or nil)
    v:set_nv('fl_door_price', state.price)
    v:set_nv('fl_door_owner', owner_id)
    v:set_nv('fl_door_text', state.text)
  end
end

--- Sets whether a door and the doors linked with it can be owned. The owner of a door
-- that stops being ownable is evicted.
-- @param entity [Entity the door]
-- @param ownable [Boolean]
function Doors:set_ownable(entity, ownable)
  local state = self:get_state(entity)

  if !ownable and state.owner then
    self:evict(entity)
  end

  state.ownable = ownable and true or false

  self:sync(entity)
end

--- Sets the price of a door and of the doors linked with it.
-- @param entity [Entity the door]
-- @param price=nil [Number the price, 0 makes the door free; nil, or a number that is not
--   finite, makes it cost what the door_price config says]
function Doors:set_price(entity, price)
  price = tonumber(price)

  if price and (price != price or price == math.huge or price == -math.huge) then
    price = nil
  end

  self:get_state(entity).price = price and math.max(price, 0) or nil

  self:sync(entity)
end

--- Returns the owner of a door.
-- @param entity [Entity the door]
-- @return [Map the owner: id (Number character ID), name (String character name), paid
--   (Number what the door was bought for) and currency (String currency ID, nil if it was
--   free); nil if the door has no owner]
function Doors:get_owner(entity)
  local state = entity.door_state

  return state and state.owner or nil
end

--- Finds the player whose active character has the given ID.
-- @param character_id [Number]
-- @return [Player the player, or nil if nobody is playing that character]
function Doors:find_character_player(character_id)
  if !character_id then return end

  for k, v in ipairs(player.GetAll()) do
    if self:get_character_id(v) == character_id then
      return v
    end
  end
end

--- Makes a character the owner of a door and of the doors linked with it, in place of the
-- owner it had. The access list and the text of the door are cleared. Nothing is checked
-- or paid here, and the door does not have to be ownable; `Doors:buy` is what players go
-- through.
-- ```
-- Doors:set_owner(entity, target:get_character_id(), target:name(true))
-- ```
-- @param entity [Entity the door]
-- @param character_id [Number ID of the character]
-- @param name='' [String name of the character, shown to staff and to those who manage
--   the door]
-- @param paid=0 [Number what was paid for the door; the refund is a share of it]
-- @param currency=nil [String ID of the currency it was paid in]
-- @return [Boolean false if the character ID is not a number]
function Doors:set_owner(entity, character_id, name, paid, currency)
  character_id = tonumber(character_id)

  if !character_id then return false end

  local root = self:get_root(entity)
  local state = self:get_state(root)
  local old_owner = state.owner

  state.owner = {
    id = character_id,
    name = isstring(name) and name or '',
    paid = tonumber(paid) or 0,
    currency = isstring(currency) and currency or nil
  }
  state.access = {}
  state.text = nil

  self:sync(root)

  --- Called on the server after the owner of a door has changed: when it is bought, sold,
  -- given with `Doors:set_owner` or taken with `Doors:clear_owner`. Not called for the
  -- owners that are restored when the doors are loaded.
  -- @param entity [Entity the door, or the main door of its group]
  -- @param owner [Map the new owner with the id, name, paid and currency fields; nil if
  --   the door has no owner anymore]
  -- @param old_owner [Map the previous owner, nil if the door had none]
  hook.Run('DoorOwnerChanged', root, state.owner, old_owner)

  return true
end

--- Takes a door and the doors linked with it away from their owner: the access list and
-- the text are cleared and the doors are unlocked. Nothing is refunded here.
-- @param entity [Entity the door]
-- @return [Boolean true if the door had an owner, Map the owner it had]
function Doors:clear_owner(entity)
  local root = self:get_root(entity)
  local state = self:get_state(root)
  local old_owner = state.owner

  if !old_owner then return false end

  state.owner = nil
  state.access = nil
  state.text = nil

  for k, v in ipairs(self:get_group(root)) do
    if v:get_nv('fl_locked') then
      self.properties['locked'].on_load(v, false)
    end
  end

  self:sync(root)

  hook.Run('DoorOwnerChanged', root, nil, old_owner)

  return true, old_owner
end

--- Takes a door away from its owner like `Doors:clear_owner` and tells the owner about it
-- if they are playing that character.
-- @param entity [Entity the door]
-- @return [Boolean true if the door had an owner]
function Doors:evict(entity)
  local success, old_owner = self:clear_owner(entity)

  if !success then return false end

  local target = self:find_character_player(old_owner.id)

  if IsValid(target) then
    target:notify('notification.door.evicted', nil, Color('salmon'))
  end

  return true
end

--- Counts the doors that a character owns. A group of linked doors counts as one.
-- @param character_id [Number ID of the character]
-- @return [Number]
function Doors:count_owned(character_id)
  local count = 0

  for k, v in ents.Iterator() do
    local state = v.door_state

    if state and state.owner and state.owner.id == character_id and !IsValid(v.door_parent) then
      count = count + 1
    end
  end

  return count
end

--- Releases every door that a character owns, without a refund, and takes away the access
-- it has to the doors of others. Used when the character is deleted.
-- @param character_id [Number ID of the character]
-- @return [Number how many doors and groups of doors were released]
function Doors:release_character(character_id)
  character_id = tonumber(character_id)

  if !character_id then return 0 end

  local released = 0

  for k, v in ents.Iterator() do
    local state = v.door_state

    if state and !IsValid(v.door_parent) then
      if state.owner and state.owner.id == character_id then
        self:clear_owner(v)

        released = released + 1
      elseif state.access and state.access[character_id] then
        self:set_access(v, character_id, DOOR_ACCESS_NONE)
      end
    end
  end

  if released > 0 then
    self:save()
  end

  return released
end

--- Puts a door, along with the doors linked to it, under the main door of a group, where
-- they share its ownership state. Nothing is checked, networked or saved here; `Doors:link`
-- is what the Door Link tool goes through and `Doors:restore_links` what the loading of the
-- doors goes through.
-- @param entity [Entity the door to link]
-- @param root [Entity the main door of the group]
function Doors:attach(entity, root)
  local moved = { entity }
  local old_parent = entity.door_parent

  if IsValid(old_parent) then
    table.RemoveByValue(old_parent.door_children or {}, entity)
  elseif entity.door_children then
    for k, v in ipairs(entity.door_children) do
      if IsValid(v) then
        table.insert(moved, v)
      end
    end

    entity.door_children = nil
  end

  local state = Doors:get_state(root)

  root.door_children = root.door_children or {}

  for k, v in ipairs(moved) do
    v.door_parent = root
    v.door_state = state

    table.insert(root.door_children, v)
  end
end

--- Links a door into the group of another door, so that the two are owned, shared and
-- labeled together. The door takes over the ownership state of the group. A door that
-- already leads a group brings its doors along; a door of another group leaves that group.
-- The doors are saved.
-- @param entity [Entity the door to link]
-- @param parent [Entity a door of the group to link it into]
-- @return [Boolean whether the door was linked, String error phrase if it was not: either
--   is not a door, they are in one group already, or the door to link has an owner]
function Doors:link(entity, parent)
  if !IsValid(entity) or !IsValid(parent) or !entity:is_door() or !parent:is_door() then
    return false, 'error.door.not_a_door'
  end

  local root = self:get_root(parent)

  if self:get_root(entity) == root then return false, 'error.door.already_linked' end
  if self:get_owner(entity) then return false, 'error.door.link_owned' end

  self:attach(entity, root)

  self:sync(root)
  self:save()

  return true
end

--- Takes a door out of the group it is linked into. The door keeps the price and the
-- ownable flag of the group but not its owner. Unlinking the main door of a group breaks
-- the whole group up, and the main door keeps the owner. The doors are saved.
-- @param entity [Entity the door]
-- @return [Boolean whether anything was unlinked, String error phrase if the door is not
--   linked to any other]
function Doors:unlink(entity)
  if !IsValid(entity) then return false, 'error.door.not_a_door' end

  local parent = entity.door_parent
  local released = {}

  if IsValid(parent) then
    table.RemoveByValue(parent.door_children or {}, entity)
    table.insert(released, entity)
  elseif entity.door_children then
    for k, v in ipairs(entity.door_children) do
      if IsValid(v) then
        table.insert(released, v)
      end
    end

    entity.door_children = nil
  end

  if #released == 0 then return false, 'error.door.not_linked' end

  local root = IsValid(parent) and parent or entity
  local state = self:get_state(root)

  for k, v in ipairs(released) do
    v.door_parent = nil
    v.door_state = { ownable = state.ownable, price = state.price }

    self:sync(v)
  end

  self:sync(root)
  self:save()

  return true
end
