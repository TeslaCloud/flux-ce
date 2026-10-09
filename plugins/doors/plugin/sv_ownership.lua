--- Door ownership, serverside: which doors can be owned, who owns them, who has access to
-- them and which doors are linked into groups.
-- Every door has an ownership state: whether it is ownable, its price, its owner, the
-- characters with access to it and the text of its owner. The doors of a group share one
-- state, so whatever is done to one of them applies to all; the group is made of a main
-- door and the doors linked to it. `Doors:buy`, `Doors:sell`, `Doors:change_access` and
-- `Doors:change_text` are what the door menu of a player asks for, with every rule checked;
-- `Doors:set_owner`, `Doors:clear_owner`, `Doors:set_access` and `Doors:set_text` change the
-- state without asking, for staff tools and other plugins. What players and staff change
-- through `Doors:buy`, `Doors:sell`, `Doors:change_access`, `Doors:change_text`, `Doors:evict`,
-- `Doors:link` and `Doors:unlink` is saved right away; the setters leave the saving to the
-- caller.

Cable.check_networked_string('fl_door_info')

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

--- Returns the access level of a character to a door.
-- @param entity [Entity the door]
-- @param character_id [Number ID of the character]
-- @return [Number DOOR_ACCESS_OWNER, DOOR_ACCESS_MANAGE, DOOR_ACCESS_USE or
--   DOOR_ACCESS_NONE]
function Doors:get_character_access(entity, character_id)
  local state = entity.door_state
  local owner = state and state.owner

  if !owner or !character_id then return DOOR_ACCESS_NONE end
  if owner.id == character_id then return DOOR_ACCESS_OWNER end

  local entry = state.access and state.access[character_id]

  return entry and entry.level or DOOR_ACCESS_NONE
end

--- Returns the access level of the active character of a player to a door.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Number DOOR_ACCESS_OWNER, DOOR_ACCESS_MANAGE, DOOR_ACCESS_USE or
--   DOOR_ACCESS_NONE]
function Doors:get_access_level(actor, entity)
  return self:get_character_access(entity, self:get_character_id(actor))
end

--- Checks whether the active character of a player owns a door or has been given access
-- to it.
-- ```
-- if Doors:has_access(actor, entity, DOOR_ACCESS_MANAGE) then
--   Doors:set_text(entity, 'Closed')
-- end
-- ```
-- @param actor [Player]
-- @param entity [Entity the door]
-- @param level=DOOR_ACCESS_USE [Number the least access level that counts]
-- @return [Boolean]
function Doors:has_access(actor, entity, level)
  return self:get_access_level(actor, entity) >= (level or DOOR_ACCESS_USE)
end

--- Gives a character access to an owned door and to the doors linked with it, changes the
-- access it has or takes it away. Nothing is checked here; `Doors:change_access` is what
-- players go through.
-- @param entity [Entity the door]
-- @param character_id [Number ID of the character, which may not be the owner]
-- @param level [Number DOOR_ACCESS_USE or DOOR_ACCESS_MANAGE; DOOR_ACCESS_NONE takes the
--   access away]
-- @param name=nil [String name to list the character under; the name it is already listed
--   under is kept if omitted]
-- @return [Boolean false if the door has no owner, the character is its owner or an
--   argument is not valid]
function Doors:set_access(entity, character_id, level, name)
  character_id = tonumber(character_id)
  level = tonumber(level)

  local root = self:get_root(entity)
  local state = self:get_state(root)
  local owner = state.owner

  if !owner or !character_id or !level or owner.id == character_id then return false end

  level = math.Clamp(math.floor(level), DOOR_ACCESS_NONE, DOOR_ACCESS_MANAGE)
  state.access = state.access or {}

  local entry = state.access[character_id]
  local old_level = entry and entry.level or DOOR_ACCESS_NONE

  if level == old_level then return true end

  if level == DOOR_ACCESS_NONE then
    state.access[character_id] = nil
  else
    state.access[character_id] = {
      level = level,
      name = isstring(name) and name or entry and entry.name or ''
    }
  end

  --- Called on the server after the access of a character to an owned door has changed.
  -- Not called when the whole access list goes because the door changes hands.
  -- @param entity [Entity the door, or the main door of its group]
  -- @param character_id [Number ID of the character]
  -- @param level [Number the new level: DOOR_ACCESS_NONE, DOOR_ACCESS_USE or
  --   DOOR_ACCESS_MANAGE]
  -- @param old_level [Number the level the character had]
  hook.Run('DoorAccessChanged', root, character_id, level, old_level)

  return true
end

--- Sets the text of the owner on a door and on the doors linked with it. The text is not
-- checked here; `Doors:change_text` is what players go through.
-- @param entity [Entity the door]
-- @param text=nil [String the text; nil or an empty string removes it]
function Doors:set_text(entity, text)
  local root = self:get_root(entity)

  self:get_state(root).text = isstring(text) and text != '' and text or nil

  self:sync(root)
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

--- Returns what the owner of a door gets back for selling it: the door_sell_share percent
-- of what the door was bought for.
-- @param entity [Entity the door]
-- @return [Number the refund, 0 if there is none, String ID of the currency of the refund,
--   nil if there is none]
function Doors:get_refund(entity)
  local owner = self:get_owner(entity)

  if !owner or !Currencies or !isstring(owner.currency) then return 0 end

  local currency_data = Currencies:find_currency(owner.currency)

  if !currency_data then return 0 end

  local share = math.Clamp(tonumber(Config.get('door_sell_share')) or 0, 0, 100)
  local refund = math.round((tonumber(owner.paid) or 0) * share / 100, currency_data.decimals or 0)

  if refund <= 0 then return 0 end

  return refund, owner.currency
end

--- Makes the active character of a player buy a door and the doors linked with it: checks
-- that the door is for sale, the door limit of the character and their money, asks the
-- PlayerCanBuyDoor hook, takes the price and makes the character the owner. The player is
-- told about a purchase; a refusal is returned for the caller to tell.
-- ```
-- local success, reason, arguments = Doors:buy(actor, entity)
--
-- if !success then
--   actor:notify(reason, arguments)
-- end
-- ```
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Boolean whether the door was bought, String error phrase if it was not, Map
--   arguments of the phrase]
function Doors:buy(actor, entity)
  local root = self:get_root(entity)
  local state = self:get_state(root)

  if !state.ownable then return false, 'error.door.not_ownable' end
  if state.owner then return false, 'error.door.already_owned' end

  local character_id = self:get_character_id(actor)

  if !character_id then return false, 'error.cant_now' end

  local limit = tonumber(Config.get('door_limit')) or 0

  if limit > 0 and self:count_owned(character_id) >= limit then
    return false, 'error.door.limit', { limit = limit }
  end

  local price, currency = self:get_price(root)
  local currency_data = currency and Currencies:find_currency(currency)

  if price > 0 and !actor:has_money(currency, price) then
    return false, 'error.door.cant_afford', { value = price, currency = currency_data.name }
  end

  --- Asks whether a player may buy a door. Called on the server once the door is known to
  -- be for sale, the character to be under its door limit and the player to have the
  -- money, before anything is taken.
  -- @param actor [Player]
  -- @param entity [Entity the door, or the main door of its group]
  -- @param price [Number what the player is about to pay, 0 if the door is free]
  -- @param currency [String ID of the currency of the price, nil if there is none]
  -- @return [Boolean return false to refuse the purchase, String error phrase to show the
  --   player, Map arguments of the phrase]
  local allowed, reason, arguments = hook.Run('PlayerCanBuyDoor', actor, root, price, currency)

  if allowed == false then
    return false, reason or 'error.door.cannot_buy', arguments
  end

  if price > 0 then
    actor:take_money(currency, price)
  end

  self:set_owner(root, character_id, actor:name(true), price, price > 0 and currency or nil)

  if price > 0 then
    actor:notify('notification.door.bought', { value = price, currency = currency_data.name }, Color('lightgreen'))
  else
    actor:notify('notification.door.taken', nil, Color('lightgreen'))
  end

  self:save()

  return true
end

--- Makes a player sell a door that their active character owns, together with the doors
-- linked with it: asks the PlayerCanSellDoor hook, pays the refund and releases the door.
-- Nothing changes if the AdjustReceivedMoney hook refuses the refund. The player is told
-- about a sale, with the refund they have actually received; a refusal is returned for the
-- caller to tell.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Boolean whether the door was sold, String error phrase if it was not, Map
--   arguments of the phrase]
function Doors:sell(actor, entity)
  local root = self:get_root(entity)

  if self:get_access_level(actor, root) < DOOR_ACCESS_OWNER then
    return false, 'error.door.not_owner'
  end

  local refund, currency = self:get_refund(root)

  --- Asks whether a player may sell a door that their character owns. Called on the
  -- server before the door is released.
  -- @param actor [Player]
  -- @param entity [Entity the door, or the main door of its group]
  -- @param refund [Number what the player is about to get back, 0 if nothing]
  -- @param currency [String ID of the currency of the refund, nil if there is none]
  -- @return [Boolean return false to refuse the sale, String error phrase to show the
  --   player, Map arguments of the phrase]
  local allowed, reason, arguments = hook.Run('PlayerCanSellDoor', actor, root, refund, currency)

  if allowed == false then
    return false, reason or 'error.door.cannot_sell', arguments
  end

  local received = 0

  if refund > 0 then
    received = actor:give_money(currency, refund, 'door_sale')

    if received == false then
      return false, 'error.money_refused'
    end
  end

  self:clear_owner(root)

  if received > 0 then
    local currency_data = Currencies:find_currency(currency)

    actor:notify('notification.door.sold', { value = received, currency = currency_data.name }, Color('lightgreen'))
  else
    actor:notify('notification.door.abandoned')
  end

  self:save()

  return true
end

--- Makes a player give a character access to a door, change the access it has or take it
-- away. The player has to manage the door (DOOR_ACCESS_MANAGE); only the owner gives and
-- takes the DOOR_ACCESS_MANAGE level. A character that is not on the access list yet has
-- to be the active character of a player on the server. The PlayerCanChangeDoorAccess
-- hook can refuse the change. Both players are told about a change; a refusal is returned
-- for the caller to tell.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @param character_id [Number ID of the character]
-- @param level [Number DOOR_ACCESS_USE or DOOR_ACCESS_MANAGE; DOOR_ACCESS_NONE takes the
--   access away]
-- @return [Boolean whether the character now has that level, String error phrase if it
--   does not, Map arguments of the phrase]
function Doors:change_access(actor, entity, character_id, level)
  character_id = tonumber(character_id)
  level = tonumber(level)

  if !character_id or !level then return false, 'error.door.invalid_character' end

  level = math.floor(level)

  if level < DOOR_ACCESS_NONE or level > DOOR_ACCESS_MANAGE then
    return false, 'error.door.invalid_character'
  end

  local root = self:get_root(entity)
  local actor_level = self:get_access_level(actor, root)

  if actor_level < DOOR_ACCESS_MANAGE then return false, 'error.door.no_access' end

  local old_level = self:get_character_access(root, character_id)

  if old_level == DOOR_ACCESS_OWNER or character_id == self:get_character_id(actor) then
    return false, 'error.door.invalid_character'
  end

  if actor_level < DOOR_ACCESS_OWNER and (level == DOOR_ACCESS_MANAGE or old_level == DOOR_ACCESS_MANAGE) then
    return false, 'error.door.owner_only'
  end

  if level == old_level then return true end

  local state = self:get_state(root)
  local access = state.access or {}
  local entry = access[character_id]
  local target = self:find_character_player(character_id)
  local name

  if entry then
    name = entry.name
  elseif IsValid(target) then
    if table.Count(access) >= (tonumber(Config.get('door_access_entries')) or 32) then
      return false, 'error.door.access_full'
    end

    --- Lets plugins change the name under which a character is put on the access list of
    -- a door, for example when the player who gives the access does not know the real
    -- name of the character. Called on the server when a character is given access to a
    -- door for the first time.
    -- @param actor [Player the player who gives the access]
    -- @param target [Player the player whose active character receives it]
    -- @param entity [Entity the door, or the main door of its group]
    -- @return [String the name to list the character under; the name of the character is
    --   used when nothing is returned]
    name = hook.Run('GetDoorAccessName', actor, target, root) or target:name(true)
  else
    return false, 'error.door.invalid_character'
  end

  --- Asks whether a player may change the access of a character to a door. Called on the
  -- server once the player is known to have the right to make the change.
  -- @param actor [Player the player who manages the door]
  -- @param entity [Entity the door, or the main door of its group]
  -- @param character_id [Number ID of the character whose access changes]
  -- @param level [Number the level it is about to have: DOOR_ACCESS_NONE, DOOR_ACCESS_USE
  --   or DOOR_ACCESS_MANAGE]
  -- @param old_level [Number the level it has now]
  -- @return [Boolean return false to refuse the change, String error phrase to show the
  --   player, Map arguments of the phrase]
  local allowed, reason, arguments = hook.Run(
    'PlayerCanChangeDoorAccess', actor, root, character_id, level, old_level
  )

  if allowed == false then
    return false, reason or 'error.door.cannot_change_access', arguments
  end

  self:set_access(root, character_id, level, name)
  self:save()

  local suffix = level == DOOR_ACCESS_MANAGE and 'manage' or level == DOOR_ACCESS_USE and 'use' or 'none'

  actor:notify('notification.door.access.'..suffix, { name = name })

  if IsValid(target) then
    target:notify('notification.door.access_received.'..suffix)
  end

  return true
end

--- Makes a player put a text on a door that they manage (DOOR_ACCESS_MANAGE). Line breaks
-- and other control characters become spaces and the text is cut to the length that the
-- door_text_length config allows; an empty text removes the text. A refusal is returned
-- for the caller to tell.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @param text [String]
-- @return [Boolean whether the text was set, String error phrase if it was not]
function Doors:change_text(actor, entity, text)
  if !isstring(text) then return false, 'error.door.invalid_text' end

  if self:get_access_level(actor, entity) < DOOR_ACCESS_MANAGE then
    return false, 'error.door.no_access'
  end

  text = string.Trim((text:gsub('%c+', ' ')))

  local length = utf8.len(text)

  if !isnumber(length) then return false, 'error.door.invalid_text' end

  local max_length = tonumber(Config.get('door_text_length')) or 32

  if length > max_length then
    text = text:utf8sub(1, max_length)
  end

  self:set_text(entity, text)
  self:save()

  return true
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
-- they share its ownership state. Nothing is checked, networked or saved here.
-- @param entity [Entity the door to link]
-- @param root [Entity the main door of the group]
local function attach(entity, root)
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

  attach(entity, root)

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

--- Returns the ownership of a door in the form it is saved in.
-- @param entity [Entity the door]
-- @return [Map `parent` (the map creation ID of the main door) for a door that is linked to
--   another, or `owner`, `access` (a List of Maps with id, name and level) and `text` for
--   a door that has an owner; nil if there is nothing to save]
function Doors:get_ownership_data(entity)
  local parent = entity.door_parent

  if IsValid(parent) then
    return { parent = parent:MapCreationID() }
  end

  local state = entity.door_state

  if !state or !state.owner then return end

  local access = {}

  for k, v in pairs(state.access or {}) do
    table.insert(access, { id = k, name = v.name, level = v.level })
  end

  return {
    owner = state.owner,
    access = access,
    text = state.text
  }
end

--- Applies saved ownership to a door. The link of a door to its main door is only
-- remembered here; `Doors:restore_links` makes it once every door has been loaded.
-- @param entity [Entity the door]
-- @param data [Map what `Doors:get_ownership_data` returned for the door; anything else
--   is ignored]
function Doors:set_ownership_data(entity, data)
  if !istable(data) then return end

  if data.parent then
    entity.door_parent_id = tonumber(data.parent)

    return
  end

  local owner = data.owner

  if !istable(owner) or !tonumber(owner.id) then return end

  local state = self:get_state(entity)

  state.owner = {
    id = tonumber(owner.id),
    name = isstring(owner.name) and owner.name or '',
    paid = tonumber(owner.paid) or 0,
    currency = isstring(owner.currency) and owner.currency or nil
  }
  state.access = {}
  state.text = isstring(data.text) and data.text != '' and data.text or nil

  if istable(data.access) then
    for k, v in pairs(data.access) do
      local character_id = istable(v) and tonumber(v.id)
      local level = istable(v) and tonumber(v.level)

      if character_id and level and level > DOOR_ACCESS_NONE and character_id != state.owner.id then
        state.access[character_id] = {
          level = math.min(math.floor(level), DOOR_ACCESS_MANAGE),
          name = isstring(v.name) and v.name or ''
        }
      end
    end
  end
end

--- Links the loaded doors to their main doors again and networks the ownership state of
-- every loaded door. Nothing is saved, since the doors are as they were saved.
-- @param doors [List<Entity> the doors that were loaded]
function Doors:restore_links(doors)
  for k, v in ipairs(doors) do
    local parent_id = v.door_parent_id

    if parent_id then
      v.door_parent_id = nil

      local parent = ents.GetMapCreatedEntity(parent_id)

      if IsValid(parent) and parent:is_door() and parent != v and self:get_root(v) != self:get_root(parent) then
        attach(v, self:get_root(parent))
      end
    end
  end

  for k, v in ipairs(doors) do
    if !IsValid(v.door_parent) then
      self:sync(v)
    end
  end
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
