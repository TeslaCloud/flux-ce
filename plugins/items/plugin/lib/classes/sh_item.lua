--- ItemBase is the class of every item: item templates and item instances are both ItemBase
-- objects, and the item base classes extend it.
-- The `item` pipeline creates one object per item file and exposes it as `ITEM`. The file
-- sets its fields and defines its callbacks, optionally after taking over those of a base
-- class with `ItemBase:base_off`.
--
-- Fields an item can set; `Item.register` fills in the defaults:
-- `name`, `print_name`, `description` and `category`; `model`, `skin`, `color` and
-- `model_bodygroups` (a table of bodygroup id or name to value, applied to the item
-- entity); `weight` and `cost`; `width` and `height` (size in inventory slots),
-- `stackable` and `max_stack`; `pocket_size` (true if the item fits into pockets);
-- `background_color` and `special_color` (background and outline of its inventory slot);
-- `icon_data`, `icon_material` and `icon_model` (how its inventory icon is rendered);
-- `use_text`, `take_text`, `drop_text`, `destroy_text`, `use_icon`, `take_icon`,
-- `drop_icon` and `destroy_icon` (options of its menu); `destroyable` (true or false to
-- let or forbid players to destroy the item whatever the `item_destroy` config says);
-- `entity_health` (how much damage the item takes while it lies in the world, instead
-- of the `item_entity_health` config; 0 makes it indestructible); and `data` (default
-- custom data, read and written with `ItemBase:get_data` and `ItemBase:set_data`).
--
-- Callbacks an item can define. Those of the first group are called on the server:
--
-- - `on_use(actor)`: a player uses the item. The use option is only shown when the item
--   has this callback. Returning true keeps the item, returning false cancels the use,
--   and returning nothing removes the item.
-- - `on_drop(actor)`: a player is about to drop the item; return false to prevent it.
-- - `on_destroy(actor)`: a player is about to destroy the item; return false, and
--   optionally an error phrase, to prevent it.
-- - `on_created()`: the instance has just been created.
-- - `on_loadout(owner)` and `on_save(owner)`: the player that has the item has spawned,
--   or their character is about to be saved.
-- - `can_transfer(inventory, x, y)` and `can_move(inventory, x, y)`: the item is about
--   to be moved to another inventory (or picked up into one) or inside of its inventory;
--   return false, and optionally an error phrase, to prevent it.
-- - `on_transfer(new_inventory, old_inventory)`: the item is about to change its inventory.
-- - `on_entity_spawned(entity)`: the item has been put into the world as an `fl_item`
--   entity, which includes the entities that are restored when the server starts.
-- - `on_entity_take_damage(entity, damage_info)`: the entity of the item is taking damage;
--   return false to ignore the damage.
-- - `on_entity_destroyed(entity, damage_info)`: the entity of the item has lost all of
--   its health and is about to be removed along with the item; return false to do
--   without the default break effect.
--
-- On the client:
--
-- - `is_action_visible(action)`: return false to hide the `'use'`, `'take'`, `'drop'` or
--   `'destroy'` option of the menu.
-- - `paint_slot(w, h)` and `paint_over_slot(w, h)`: draw on the inventory slot of the item.
-- - `on_entity_draw(entity)`: the entity of the item is about to be drawn; return false
--   to keep its model from being drawn.
--
-- And on both:
--
-- - `on_entity_think(entity)`: called for the entity of the item once a second; return
--   a number to be called again in that many seconds instead (0.1 at least).
-- - `on_entity_removed(entity)`: the entity of the item is being removed, be it because
--   the item was picked up or destroyed or because the map is being cleaned up or shut
--   down. A client also gets the call when it merely stops receiving the entity.
--
-- Custom menu options are added with `ItemBase:add_button`, and every menu action goes
-- through `ItemBase:do_menu_action`.

class 'ItemBase'

--- Initializes a new item table.
-- The 'item' pipeline creates one for every item file and exposes it as ITEM.
-- @param id [String item id; gets converted with string.to_id]
function ItemBase:init(id)
  if !isstring(id) then return end

  self.id = string.to_id(id)
  self.data = self.data or {}
  self.bases = self.bases or {}
  self.base_count = 0
end

--- Fancy output if you do print(item_obj).
-- @return [String e.g. '#<Item:Test Item 12>']
function ItemBase:__tostring()
  return '#<Item:'..(self.name or self.id)..' '..tostring(self.instance_id)..'>'
end

--- Returns the name of the item that is shown to players.
-- @return [String print name of the item, or its name if there is none]
function ItemBase:get_name()
  return self.print_name or self.name
end

ItemBase.name = ItemBase.get_name

--- Bases the item off an item base.
-- Copies every function of the base, and every other field that the item has not set yet.
-- Also available as ItemBase:derive.
-- ```
-- ITEM:base_off 'ItemContainer'
-- ITEM.name = 'Test Bag'
-- ```
-- @param what [String/Map name of the base class ('Item' prefix may be omitted), or the class]
function ItemBase:base_off(what)
  if isstring(what) then
    what = what:capitalize()
  end

  local module_table = isstring(what) and (what:parse_table() or ('Item'..what):parse_table()) or what

  if !istable(module_table) then return end

  for k, v in pairs(module_table) do
    if !self[k] or isfunction(v) then
      self[k] = v
    end
  end

  self.bases[module_table.class_name] = module_table

  if isstring(what) then
    self.bases[what] = module_table
  end

  self.base_count = self.base_count + 1
end

--- Checks whether the item was based off the specified item base with ItemBase:base_off.
-- Also available as ItemBase:based_off.
-- @param base [String/Map name of the base class ('Item' prefix may be omitted), or the class]
-- @return [Boolean]
function ItemBase:is(base)
  if isstring(base) then
    base = base:capitalize()
    return (self.bases[base] or self.bases['Item'..base]) != nil
  elseif istable(base) then
    for k, v in pairs(self.bases) do
      if base.class_name == v.class_name then
        return true
      end
    end
  end

  return false
end

ItemBase.based_off = ItemBase.is
ItemBase.derive = ItemBase.base_off

--- Returns the internal name of the item, ignoring its print name.
-- @return [String]
function ItemBase:get_real_name()
  return self.name or 'Unknown Item'
end

--- Returns the description of the item.
-- @return [String]
function ItemBase:get_description()
  return self.description or 'This item has no description!'
end

--- Returns the weight of the item.
-- @return [Number]
function ItemBase:get_weight()
  return self.weight or 1
end

--- Returns how many items of this kind can be stacked in a single inventory slot.
-- @return [Number]
function ItemBase:get_max_stack()
  return self.max_stack or 1
end

--- Returns the model of the item.
-- @return [String path to the model]
function ItemBase:get_model()
  return self.model or 'models/props_lab/cactus.mdl'
end

--- Returns the skin of the item's model.
-- @return [Number]
function ItemBase:get_skin()
  return self.skin or 0
end

--- Returns the color of the item's model.
-- @return [Color white if the item has no color set]
function ItemBase:get_color()
  return self.color or Color(255, 255, 255)
end

--- Returns the bodygroups of the item's model, which the entity of the item is given when
-- the item lies in the world.
-- ```
-- ITEM.model_bodygroups = {
--   [1] = 2,
--   ['strap'] = 1
-- }
-- ```
-- @return [Map bodygroup id (Number) or bodygroup name (String) to its value, or nil if
--   the item leaves the bodygroups of its model alone]
-- @see [Item.apply_bodygroups]
function ItemBase:get_model_bodygroups()
  return self.model_bodygroups
end

--- Returns the health that the entity of the item gets when the item is put into the
-- world: the entity_health of the item, or the 'item_entity_health' config if the item
-- has none.
-- @return [Number 0 if the item cannot be destroyed by damage]
function ItemBase:get_entity_health()
  local health = self.entity_health

  if !isnumber(health) then
    health = Config.get('item_entity_health')
  end

  return isnumber(health) and math.max(health, 0) or 0
end

--- Checks whether players may destroy the item through its menu: the destroyable field of
-- the item if it is set, and the 'item_destroy' config otherwise.
-- @return [Boolean]
function ItemBase:is_destroyable()
  if self.destroyable != nil then
    return self.destroyable == true
  end

  return Config.get('item_destroy') == true
end

--- Returns the camera setup that is used to render the item's model in inventory slots.
-- @return [Map table with origin (Vector), angles (Angle) and fov (Number) fields,
--   or nil to position the camera automatically]
function ItemBase:get_icon_data()
  return self.icon_data
end

--- Returns the material that is drawn in inventory slots instead of the item's model.
-- @return [String path to the material, or nil if the model should be drawn]
function ItemBase:get_icon_material()
  return self.icon_material
end

--- Adds a custom button to the menu of the item.
-- ```
-- ITEM:add_button('item.option.open', {
--   icon = 'icon16/briefcase.png',
--   -- Calls ITEM:on_open(actor) on the server when the button is pressed.
--   callback = 'on_open',
--   -- Client-side. The button is hidden if this returns false.
--   on_show = function(item_obj)
--     return !IsValid(item_obj.entity)
--   end
-- })
-- ```
-- @param name [String id of the button; also its title, unless data has name or get_name]
-- @param data [Map button data: icon (String), callback (String name of the item's method
--   to call on the server), and optionally name (String) or the client-side functions
--   get_name, get_icon, on_show and on_click, each of which receives the item]
function ItemBase:add_button(name, data)
  --[[
    Example data structure:
    data = {
      icon = 'path/to/icon.png',
      callback = 'on_use', -- This will call the ITEM:on_use function when the button is pressed.
      on_show = function(item_obj) -- Client-Side function. Determines whether the button will be shown.
        return true
      end
    }
  --]]

  if !self.custom_buttons then
    self.custom_buttons = {}
  end

  self.custom_buttons[name] = data
end

--- Checks whether clients may request a menu action of the item: 'on_take' and 'on_drop'
-- always, 'on_use' if the item has an on_use callback, 'on_destroy' if the item is
-- destroyable, and the callbacks of the item's custom buttons. The server ignores requests
-- for anything else, so that a client cannot call arbitrary methods of the item.
-- @param act [String name of the action]
-- @return [Boolean]
-- @see [ItemBase#add_button]
-- @see [ItemBase#is_destroyable]
function ItemBase:has_menu_action(act)
  if act == 'on_take' or act == 'on_drop' then
    return true
  end

  if act == 'on_use' then
    return self.on_use != nil
  end

  if act == 'on_destroy' then
    return self:is_destroyable()
  end

  if self.custom_buttons then
    for k, v in pairs(self.custom_buttons) do
      if v.callback == act then
        return true
      end
    end
  end

  return false
end

--- Sets the sound that is emitted when a menu action is performed on the item.
-- @param act [String name of the action, e.g. 'on_drop']
-- @param sound_path [String path to the sound]
-- @see [ItemBase#do_menu_action]
-- @see [ItemBase#play_sound]
function ItemBase:set_action_sound(act, sound_path)
  if !self.action_sounds then
    self.action_sounds = {}
  end

  self.action_sounds[act] = sound_path
end

--- Plays the sound of a menu action, if the item has one.
-- The sound is emitted by the item's entity if it is in the world. Otherwise it is emitted
-- by the player that has the item, which can only be looked up on the server.
-- @param act [String name of the action, e.g. 'on_drop']
-- @param emitter=nil [Entity who emits the sound if the item is not in the world; the player
--   that has the item if nil]
-- @see [ItemBase#set_action_sound]
function ItemBase:play_sound(act, emitter)
  local sound_path = self.action_sounds and self.action_sounds[act]

  if !sound_path then return end

  if IsValid(self.entity) then
    emitter = self.entity
  elseif !IsValid(emitter) and SERVER then
    emitter = self:get_player()
  end

  if IsValid(emitter) then
    emitter:EmitSound(sound_path)
  end
end

--- Called on the server by the 'CanPlayerDropItem' hook when a player is about to drop the item.
-- Returning nothing/nil drops the item like normal, returning false
-- prevents the item from appearing and doesn't remove it from the inventory.
-- @param actor [Player]
-- @return [Boolean false to prevent the drop, nil otherwise]
function ItemBase:on_drop(actor) end

--- Called on the server when a player is about to destroy the item through its menu, after
-- the 'PlayerCanDestroyItem' hook has allowed it. Returning nothing/nil lets the item be
-- destroyed, returning false keeps it where it is.
-- @param actor [Player]
-- @return [Boolean false to prevent the destruction, String error phrase to notify the
--   player with; nothing otherwise]
function ItemBase:on_destroy(actor) end

--- Called on the server right after the player that has the item spawns with their character
-- loaded. Override it to give the player whatever the item is supposed to provide.
-- @param owner [Player]
function ItemBase:on_loadout(owner) end

--- Called on the server before the character of the player that has the item is saved.
-- Override it to store the state of the item.
-- @param owner [Player]
function ItemBase:on_save(owner) end

if SERVER then
  --- Sets a custom data value of the item. Server-side only.
  -- The data is then sent to the player that has the item, or to everyone if nobody has it.
  -- @param id [String data key]
  -- @param value [Any]
  function ItemBase:set_data(id, value)
    if !id then return end

    self.data[id] = value

    Item.network_item_data(self:get_player(), self)
  end

  --- Finds the player that has the item in one of their inventories. Server-side only.
  -- @return [Player the player, or nil if no player has the item]
  function ItemBase:get_player()
    for k, v in player.Iterator() do
      if v:has_item_by_id(self.instance_id) then
        return v
      end
    end
  end

  --- Performs a menu action on the item on behalf of the player.
  -- Runs the 'PlayerCanUseItem' hook and then the hook of the action ('PlayerTakeItem',
  -- 'PlayerUseItem', 'PlayerDropItem' or 'PlayerDestroyItem'). Every action except 'on_use',
  -- 'on_take', 'on_drop' and 'on_destroy' also calls the item's method of the same name with
  -- the player and the extra arguments. Runs the 'PlayerUsedItem' hook when done.
  -- ```
  -- -- Makes the player pick up the item into their hotbar.
  -- item_obj:do_menu_action('on_take', actor, { inv_type = 'hotbar' })
  -- ```
  -- @param act [String 'on_use', 'on_take', 'on_drop', 'on_destroy' or the callback of a
  --   custom button]
  -- @param actor [Player the player performing the action]
  -- @param ... [Vararg extra arguments that are passed to the hooks and to the item's method]
  function ItemBase:do_menu_action(act, actor, ...)
    --- Called on the server before a player performs any menu action on an item:
    -- using, taking, dropping or destroying it, or pressing one of its custom buttons.
    -- The Items plugin uses it to reject actions on items the player does not have and
    -- on items in the world that are out of reach.
    -- @param actor [Player The player performing the action]
    -- @param item_obj [Item The item instance]
    -- @param act [String Name of the action: `'on_use'`, `'on_take'`, `'on_drop'`,
    --   `'on_destroy'` or the callback of a custom button]
    -- @param ... [Vararg Extra arguments that were passed to `ItemBase:do_menu_action`]
    -- @return [Boolean Return false to prevent the action]
    if hook.Run('PlayerCanUseItem', actor, self, act, ...) == false then return end

    if act == 'on_take' then
      --- Called on the server when a player takes an item, after `PlayerCanUseItem`.
      -- The hook is what performs the action: the Inventory plugin handles it by putting
      -- an item that lies in the world into one of the player's inventories.
      -- @param actor [Player The player taking the item]
      -- @param item_obj [Item The item instance]
      -- @param ... [Vararg Extra arguments of the action; a table with an `inv_type` field
      --   names the inventory type the item should go to]
      -- @return [Any Any value other than nil ends the action right there: the action
      --   sound is not played and `PlayerUsedItem` is not run]
      if hook.Run('PlayerTakeItem', actor, self, ...) != nil then return end
    end

    if act == 'on_use' then
      --- Called on the server when a player uses an item, after `PlayerCanUseItem`.
      -- The hook is what performs the action: the Inventory plugin handles it by calling
      -- the `on_use` callback of the item and removing the item afterward, unless the
      -- callback returns true to keep it. It returns false when the callback cancels the
      -- use.
      -- @param actor [Player The player using the item]
      -- @param item_obj [Item The item instance]
      -- @param ... [Vararg Extra arguments that were passed to `ItemBase:do_menu_action`]
      -- @return [Any Any value other than nil ends the action right there: the action
      --   sound is not played and `PlayerUsedItem` is not run]
      if hook.Run('PlayerUseItem', actor, self, ...) != nil then return end
    end

    if act == 'on_drop' then
      --- Called on the server when a player drops an item through its menu, after
      -- `PlayerCanUseItem`. The hook is what performs the action: the Inventory plugin
      -- handles it by taking the item out of its inventory and spawning it in front of
      -- the player. The Inventory plugin also runs this hook itself, with a list of
      -- instance ids instead of a single one, when items are dragged out of an inventory
      -- panel.
      -- @param actor [Player The player dropping the item]
      -- @param instance_id [Number Instance id of the item]
      -- @return [Any Any value other than nil ends the action right there: the action
      --   sound is not played and `PlayerUsedItem` is not run]
      if hook.Run('PlayerDropItem', actor, self.instance_id) != nil then return end
    end

    if act == 'on_destroy' then
      --- Called on the server when a player destroys an item through its menu, after
      -- `PlayerCanUseItem`. The hook is what performs the action: the Items plugin
      -- handles it by asking the `PlayerCanDestroyItem` hook and the `on_destroy` callback
      -- of the item, taking the item out of its inventory and removing the instance for
      -- good. Only items that are in an inventory can be destroyed this way; the client
      -- asks the player to confirm before it sends the request.
      -- @param actor [Player The player destroying the item]
      -- @param item_obj [Item The item instance]
      -- @param ... [Vararg Extra arguments that were passed to `ItemBase:do_menu_action`]
      -- @return [Any Any value other than nil ends the action right there: the action
      --   sound is not played and `PlayerUsedItem` is not run. The Items plugin returns
      --   false when the item has not been destroyed]
      if hook.Run('PlayerDestroyItem', actor, self, ...) != nil then return end
    end

    if self[act] then
      if act != 'on_take' and act != 'on_use' and act != 'on_drop' and act != 'on_destroy' then
        local success, exception = pcall(self[act], self, actor, ...)

        if !success then
          error_with_traceback('Item callback has failed to run! '..tostring(exception))
          return
        end
      end

      self:play_sound(act, actor)
    end

    --- Called on the server after a player has performed a menu action on an item.
    -- It is not run when the action was rejected by `PlayerCanUseItem` or ended by a
    -- handler of `PlayerTakeItem`, `PlayerUseItem`, `PlayerDropItem` or
    -- `PlayerDestroyItem`. After the `'on_destroy'` action the item is a removed instance.
    -- @param actor [Player The player who performed the action]
    -- @param item_obj [Item The item instance]
    -- @param act [String Name of the action: `'on_use'`, `'on_take'`, `'on_drop'`,
    --   `'on_destroy'` or the callback of a custom button]
    -- @param ... [Vararg Extra arguments that were passed to `ItemBase:do_menu_action`]
    hook.Run('PlayerUsedItem', actor, self, act, ...)
  end

  Cable.receive('fl_items_menu_action', function(actor, instance_id, action, ...)
    local item_obj = Item.find_instance_by_id(instance_id)

    if !item_obj or !item_obj:has_menu_action(action) then return end

    item_obj:do_menu_action(action, actor, ...)
  end)
else
  --- Asks the server to perform a menu action on the item on behalf of the local player.
  -- The server ignores the actions that ItemBase:has_menu_action does not allow.
  -- @param act [String 'on_use', 'on_take', 'on_drop', 'on_destroy' or the callback of a
  --   custom button]
  -- @param ... [Vararg extra arguments to send to the server]
  function ItemBase:do_menu_action(act, ...)
    Cable.send('fl_items_menu_action', self.instance_id, act, ...)
  end

  --- Returns the title of the 'use' option in the item's menu. Client-side only.
  -- @return [String language phrase]
  function ItemBase:get_use_text()
    return self.use_text or 'item.option.use'
  end

  --- Returns the title of the 'take' option in the item's menu. Client-side only.
  -- @return [String language phrase]
  function ItemBase:get_take_text()
    return self.take_text or 'item.option.take'
  end

  --- Returns the title of the 'drop' option in the item's menu. Client-side only.
  -- @return [String language phrase]
  function ItemBase:get_drop_text()
    return self.drop_text or 'item.option.drop'
  end

  --- Returns the title of the 'destroy' option in the item's menu. Client-side only.
  -- @return [String language phrase]
  function ItemBase:get_destroy_text()
    return self.destroy_text or 'item.option.destroy'
  end

  --- Returns the title of the 'cancel' option in the item's menu. Client-side only.
  -- @return [String language phrase]
  function ItemBase:get_cancel_text()
    return self.cancel_text or 'item.option.cancel'
  end

  --- Returns the model that is shown in inventory slots instead of the item's own model.
  -- Client-side only.
  -- @return [String path to the model, or nil if the item's own model should be shown]
  function ItemBase:get_icon_model()
    return self.icon_model
  end
end

--- Returns a custom data value of the item.
-- @param id [String data key]
-- @param default=nil [Any what to return if the value is not set]
-- @return [Any the value, or the default if the value is not set]
function ItemBase:get_data(id, default)
  if !id then return end

  local data = self.data[id]

  if data != nil then
    return data
  else
    return default
  end
end

--- Ties the item to the entity that represents it in the world.
-- @param ent [Entity]
function ItemBase:set_entity(ent)
  self.entity = ent
end

--- Registers the item as an item template under its id.
-- @see [Item.register]
function ItemBase:register()
  return Item.register(self.id, self)
end
