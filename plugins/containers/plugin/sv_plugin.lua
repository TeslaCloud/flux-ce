--- Server side of the Containers plugin: creates the inventory of a container and opens it
-- for a player, asking for its password first if it has one; sets the name, the message
-- and the password of a container and networks what clients may know of them; fills a
-- container with random items; and destroys or spills the items of a removed container.

local name_length = 64
local message_length = 256
local password_length = 64
local password_timeout = 60

--- Cleans a text that was entered by a player: replaces control characters with spaces,
-- trims the text and cuts it to the given length.
-- @param text [String the text; anything else gives nil]
-- @param max_length [Number longest allowed text in characters]
-- @return [String the cleaned text, or nil if nothing is left of it]
local function sanitize(text, max_length)
  if !isstring(text) then return end

  text = string.Trim((text:gsub('%c', ' ')))

  local length = utf8.len(text)

  if !isnumber(length) then
    text = text:sub(1, max_length)
  elseif length > max_length then
    text = text:utf8sub(1, max_length)
  end

  if text != '' then
    return text
  end
end

--- Counts the slots of an inventory that have items in them.
-- @param inventory [Inventory]
-- @return [Number]
local function count_used_slots(inventory)
  local used = 0

  for y = 1, inventory:get_height() do
    for x = 1, inventory:get_width() do
      local slot = inventory:get_slot(x, y)

      if istable(slot) and !table.IsEmpty(slot) then
        used = used + 1
      end
    end
  end

  return used
end

--- Closes an inventory for every player who has it open.
-- @param inventory [Inventory]
local function close_for_receivers(inventory)
  local receivers = inventory.receivers

  for i = #receivers, 1, -1 do
    local receiver = receivers[i]

    if IsValid(receiver) then
      receiver:close_inventory(inventory)
    end
  end
end

--- Checks whether an item is somewhere else than in the inventory that is being emptied:
-- lying in the world, or in the slots of another inventory. The list of items that a
-- container is saved with can be out of date after a crash, and such items are left alone.
-- @param item_obj [Item]
-- @param inventory [Inventory the inventory that is being emptied, nil if it was never
--   created]
-- @return [Boolean]
local function is_held_elsewhere(item_obj, inventory)
  if IsValid(item_obj.entity) then
    return true
  end

  local holder = item_obj.inventory_id and Inventories.find(item_obj.inventory_id)

  return holder != nil and holder != inventory and holder:has_item_by_id(item_obj.instance_id)
end

--- Removes item instances for good, along with everything that the container items among
-- them hold.
-- @param item_ids [List<Number> instance ids]
-- @param inventory [Inventory the inventory the items are in, nil if it was never created]
-- @param seen=nil [Map instance ids that have been dealt with already]
local function destroy_items(item_ids, inventory, seen)
  seen = seen or {}

  for k, instance_id in pairs(item_ids) do
    local item_obj = !seen[instance_id] and Item.find_instance_by_id(instance_id)

    seen[instance_id] = true

    if item_obj and !is_held_elsewhere(item_obj, inventory) then
      local inner_inventory = item_obj.inventory

      if inner_inventory then
        destroy_items(inner_inventory:get_items_ids(), inner_inventory, seen)

        Inventories.stored[inner_inventory.id] = nil
      elseif istable(item_obj.items) then
        destroy_items(item_obj.items, nil, seen)
      end

      Item.remove(item_obj)
    end
  end
end

--- Takes items out of a container and puts them into the world around the place where it
-- was.
-- @param origin [Vector the center of the container prop]
-- @param inventory [Inventory the inventory of the container, nil if it was never created]
-- @param item_ids [List<Number> instance ids of the items of the container]
local function spill_items(origin, inventory, item_ids)
  for k, instance_id in pairs(item_ids) do
    local item_obj = Item.find_instance_by_id(instance_id)

    if item_obj and !is_held_elsewhere(item_obj, inventory) then
      if inventory then
        inventory:take_item_table(item_obj)
      else
        item_obj.inventory_id = nil
        item_obj.inventory_type = nil
        item_obj.x = nil
        item_obj.y = nil
        item_obj.rotated = false
      end

      Item.spawn(origin + VectorRand() * 8, Angle(0, math.random(0, 359), 0), item_obj)
    end
  end
end

--- Sends what clients may know about a container to them: its custom name and whether it
-- has a password. Called whenever either changes and after the saved containers are loaded.
-- @param entity [Entity the container prop]
function Container:update_netvars(entity)
  entity:set_nv('fl_container_name', entity.container_name)
  entity:set_nv('fl_container_locked', entity.container_password != nil or nil)
end

--- Returns the inventory of a container, creating it and loading the saved items into it
-- if the container has not been opened since the server started.
-- @param entity [Entity the container prop]
-- @return [Inventory the inventory, or nil if the entity is not a container]
function Container:get_inventory(entity)
  local container_data = self:get_container_data(entity)

  if !container_data then return end

  if !entity.inventory then
    local inventory = Inventory.new()
    inventory:set_size(container_data.w, container_data.h)
    inventory.title = self:get_container_name(entity)
    inventory.type = 'container'
    inventory.multislot = true
    inventory.owner = entity

    if entity.items then
      inventory:load_items(entity.items)

      entity.items = nil
    end

    entity.inventory = inventory
  end

  return entity.inventory
end

--- Gives a container a name of its own, which replaces the name of its model in its target
-- text and in the title of its inventory.
-- ```
-- Container:set_container_name(entity, 'Evidence locker')
-- -- Back to the name registered for the model.
-- Container:set_container_name(entity)
-- ```
-- @param entity [Entity the container prop]
-- @param name=nil [String the name, cut to 64 characters; nil or an empty text removes the
--   custom name]
-- @return [String the name that was set, or nil if the container has none now or the
--   entity is not a container]
function Container:set_container_name(entity, name)
  if !self:is_container(entity) then return end

  name = sanitize(name, name_length)

  entity.container_name = name

  self:update_netvars(entity)

  local inventory = entity.inventory

  if inventory then
    inventory.title = self:get_container_name(entity)
    inventory:sync()
  end

  return name
end

--- Returns the message that is shown to the players who open a container.
-- @param entity [Entity the container prop]
-- @return [String the message, or nil if the container has none]
function Container:get_container_message(entity)
  return entity.container_message
end

--- Sets the message that is shown to the players who open a container.
-- @param entity [Entity the container prop]
-- @param message=nil [String the message, cut to 256 characters; nil or an empty text
--   removes it]
-- @return [String the message that was set, or nil if the container has none now or the
--   entity is not a container]
function Container:set_container_message(entity, message)
  if !self:is_container(entity) then return end

  message = sanitize(message, message_length)

  entity.container_message = message

  return message
end

--- Sets the password that a player has to enter to open a container, and closes the
-- container for those who have it open. The password is never sent to clients.
-- @param entity [Entity the container prop]
-- @param password=nil [String the password, cut to 64 characters; nil or an empty text
--   removes it]
-- @return [String the password that was set, or nil if the container has none now or the
--   entity is not a container]
function Container:set_container_password(entity, password)
  if !self:is_container(entity) then return end

  password = sanitize(password, password_length)

  entity.container_password = password

  self:update_netvars(entity)

  if password and entity.inventory then
    close_for_receivers(entity.inventory)
  end

  return password
end

--- Checks a text against the password of a container. The spaces around the text are
-- ignored, as they are when the password is set.
-- @param entity [Entity the container prop]
-- @param password [String the text to check]
-- @return [Boolean true if the text is the password; false if it is not, or if the
--   container has no password]
function Container:check_container_password(entity, password)
  local expected = entity.container_password

  return expected != nil and sanitize(password, password_length) == expected
end

--- Checks whether a player may open a container right now: the entity has to be a
-- container within reach of the player, and the `PlayerCanOpenContainer` hook must not
-- object. The password of the container is not a part of this check.
-- @param actor [Player]
-- @param entity [Entity the container prop]
-- @return [Boolean true if the player may open the container, String error phrase when
--   they may not and there is something to tell them]
function Container:can_open(actor, entity)
  if !self:is_container(entity) then
    return false
  end

  if !Inventories.is_in_reach(actor, entity) then
    return false, 'error.too_far'
  end

  --- Called on the server before a container is opened for a player who has asked for it,
  -- and once more after they have entered its password. The entity is a container within
  -- reach of the player at this point.
  -- @param actor [Player The player who wants to open the container]
  -- @param entity [Entity The container prop]
  -- @return [Boolean Return false to keep the container closed for the player, String
  --   Error phrase to notify the player with]
  local allowed, reason = hook.Run('PlayerCanOpenContainer', actor, entity)

  if allowed == false then
    return false, reason
  end

  return true
end

--- Opens a container for a player without any checks: plays its opening sound, runs the
-- `PreContainerOpen` hook, shows its inventory and its message to the player.
-- @param actor [Player]
-- @param entity [Entity the container prop]
-- @return [Boolean true if the container was opened, false if the entity is not a container]
function Container:open(actor, entity)
  local container_data = self:get_container_data(entity)

  if !container_data then return false end

  local inventory = self:get_inventory(entity)

  if container_data.open_sound then
    entity:EmitSound(container_data.open_sound, 55)
  end

  --- Called on the server when a container is opened for a player, after its inventory has
  -- been created or found and its opening sound played, right before the inventory is
  -- shown to the player.
  -- @param entity [Entity the container prop; its inventory is entity.inventory]
  -- @param actor [Player the player the container is opened for]
  hook.Run('PreContainerOpen', entity, actor)

  actor:open_inventory(inventory)

  local message = entity.container_message

  if message then
    actor:notify('notification.container.message', {
      name = self:get_container_name(entity) or '',
      message = message
    })
  end

  return true
end

--- Handles the password that a player has entered for a container: opens the container if
-- it is right, and makes the player wait before the next attempt if it is wrong.
-- @param actor [Player]
-- @param entity [Entity the container prop]
-- @param answer [String the entered text]
local function submit_password(actor, entity, answer)
  local allowed, reason = Container:can_open(actor, entity)

  if !allowed then
    if reason then
      actor:notify(reason)
    end

    return
  end

  local correct = !Container:has_container_password(entity)
    or Container:check_container_password(entity, answer)

  --- Called on the server when a player has entered the password of a container, before
  -- the container is opened or the player is told that the password is wrong.
  -- @param actor [Player The player who entered the password]
  -- @param entity [Entity The container prop]
  -- @param correct [Boolean Whether the password was right; also true if the password of
  --   the container was removed while the player was typing]
  hook.Run('PlayerEnteredContainerPassword', actor, entity, correct)

  if correct then
    Container:open(actor, entity)
  else
    actor.next_container_password = CurTime() + Config.get('container_password_delay', 3)
    actor:notify('error.container.wrong_password')
  end
end

--- Asks a player for the password of a container, unless they have entered a wrong one
-- too recently. A question that the player has not answered yet is replaced.
-- @param actor [Player]
-- @param entity [Entity the container prop]
local function ask_password(actor, entity)
  local time_left = (actor.next_container_password or 0) - CurTime()

  if time_left > 0 then
    actor:notify('error.container.password_wait', {
      time = Flux.Lang:duration(math.ceil(time_left))
    })

    return
  end

  if actor.container_prompt then
    Flux.Prompt:cancel(actor.container_prompt)
  end

  local prompt_id

  prompt_id = actor:request_string(
    'ui.container.password.title',
    'ui.container.password.message',
    function(target, answer)
      if !IsValid(target) then return end

      if target.container_prompt == prompt_id then
        target.container_prompt = nil
      end

      if answer then
        submit_password(target, entity, answer)
      end
    end,
    { max_length = password_length, timeout = password_timeout }
  )

  actor.container_prompt = prompt_id
end

--- Opens a container for a player the way the 'open' option of its interaction menu does:
-- checks that the player may open it, then opens it right away, or asks for its password
-- first if it has one.
-- @param actor [Player]
-- @param entity [Entity the container prop]
-- @return [Boolean true if the container was opened; false if it was not, or not yet
--   because the player has been asked for the password]
function Container:request_open(actor, entity)
  local allowed, reason = self:can_open(actor, entity)

  if !allowed then
    if reason then
      actor:notify(reason)
    end

    return false
  end

  if self:has_container_password(entity) then
    --- Called on the server when a player is about to be asked for the password of a
    -- container that they may otherwise open.
    -- @param actor [Player The player who wants to open the container]
    -- @param entity [Entity The container prop]
    -- @return [Boolean Return false to open the container for the player without the
    --   password]
    if hook.Run('ShouldAskContainerPassword', actor, entity) != false then
      ask_password(actor, entity)

      return false
    end
  end

  return self:open(actor, entity)
end

--- Fills a container with random items until the given share of its slots is taken. Items
-- are picked with `Container:get_loot_items`; an item that does not fit, or that would
-- take the container past the share, is skipped. What is in the container already counts
-- towards the share.
-- ```
-- -- Fills half of the container with food and drinks.
-- local added, error_text = Container:fill(entity, 0.5, 'item.category.consumables')
-- ```
-- @param entity [Entity the container prop]
-- @param share=1 [Number share of the slots to fill, from 0 to 1]
-- @param category=nil [String item category to pick from; all categories if nil]
-- @return [Number amount of items that were added, or false if nothing could be added,
--   String error phrase when nothing could be added]
function Container:fill(entity, share, category)
  local inventory = self:get_inventory(entity)

  if !inventory then
    return false, 'error.container.not_valid'
  end

  local candidates = self:get_loot_items(category)

  if #candidates == 0 then
    return false, 'error.container.no_items'
  end

  local capacity = inventory:get_width() * inventory:get_height()
  local target = math.floor(capacity * math.Clamp(tonumber(share) or 1, 0, 1) + 0.5)
  local used = count_used_slots(inventory)
  local added = 0
  local attempts = 0

  while used < target and added < target and attempts < capacity * 4 do
    local item_table = candidates[math.random(#candidates)]
    local w, h = inventory:get_item_size(item_table)
    local x, y = inventory:find_position(item_table, w, h)

    attempts = attempts + 1

    if x and y then
      local stacked = !table.IsEmpty(inventory:get_slot(x, y))

      if stacked or used + w * h <= target then
        if !inventory:give_item(item_table.id) then break end

        added = added + 1
        used = count_used_slots(inventory)
      end
    end
  end

  if added == 0 then
    return false, 'error.container.no_space'
  end

  inventory:sync()

  return added
end

--- Deals with the items of a container whose prop is being removed: drops them on the
-- ground if the `container_spill_items` config is on and destroys them otherwise, and
-- runs the `OnContainerRemoved` hook. Does nothing while the server is shutting down or
-- changing the map, or while the map is being cleaned up: the containers are saved then,
-- with the IDs of their items, to come back with them. Items that turn out to be in the
-- world or in another inventory are left alone.
--
-- The items are dropped or destroyed on the next tick. A map that is unloading never gets
-- there, so the saved items of the containers are safe even if the shutdown was not
-- noticed, because the save that comes before it has failed, for example.
-- @param entity [Entity the container prop]
-- @param inventory [Inventory the inventory of the container, nil if it was never created]
-- @param item_ids [List<Number> instance ids of the items of the container]
function Container:handle_removal(entity, inventory, item_ids)
  if Flux.shutting_down or self.cleaning_up then return end

  local spilled = Config.get('container_spill_items', false) == true

  if !table.IsEmpty(item_ids) then
    local origin = entity:WorldSpaceCenter()

    timer.Simple(0, function()
      if spilled then
        spill_items(origin, inventory, item_ids)
      else
        destroy_items(item_ids, inventory)
      end
    end)
  end

  --- Called on the server when a container prop is removed from a running server. It is
  -- run for every removed prop with a container model, whether it held anything or not.
  -- The prop is still valid at this point and its inventory is not registered anymore;
  -- its items are dropped on the ground or destroyed on the next tick. It is not run when
  -- the map unloads or is cleaned up.
  -- @param entity [Entity The container prop that is being removed]
  -- @param spilled [Boolean true if the items are dropped on the ground, false if they
  --   are destroyed]
  hook.Run('OnContainerRemoved', entity, spilled)
end
