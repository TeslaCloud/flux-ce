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
-- @param what [String/Hash name of the base class ('Item' prefix may be omitted), or the class]
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
-- @param base [String/Hash name of the base class ('Item' prefix may be omitted), or the class]
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

--- Returns the camera setup that is used to render the item's model in inventory slots.
-- @return [Hash table with origin (Vector), angles (Angle) and fov (Number) fields,
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
--   -- Calls ITEM:on_open(player) on the server when the button is pressed.
--   callback = 'on_open',
--   -- Client-side. The button is hidden if this returns false.
--   on_show = function(item_obj)
--     return !IsValid(item_obj.entity)
--   end
-- })
-- ```
-- @param name [String id of the button; also its title, unless data has name or get_name]
-- @param data [Hash button data: icon (String), callback (String name of the item's method
--   to call on the server), and optionally name (String) or the client-side functions
--   get_name, on_show and on_click, each of which receives the item]
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

--- Sets the sound that the player emits when a menu action is performed on the item.
-- @param act [String name of the action, e.g. 'on_drop']
-- @param sound [String path to the sound]
-- @see [ItemBase#do_menu_action]
function ItemBase:set_action_sound(act, sound)
  self.action_sounds[act] = sound
end

--- Called on the server by the 'CanPlayerDropItem' hook when a player is about to drop the item.
-- Returning nothing/nil drops the item like normal, returning false
-- prevents the item from appearing and doesn't remove it from the inventory.
-- @param player [Player]
-- @return [Boolean false to prevent the drop, nil otherwise]
function ItemBase:on_drop(player) end

--- Called on the server right after the player that has the item spawns with their character
-- loaded. Override it to give the player whatever the item is supposed to provide.
-- @param player [Player]
function ItemBase:on_loadout(player) end

--- Called on the server before the character of the player that has the item is saved.
-- Override it to store the state of the item.
-- @param player [Player]
function ItemBase:on_save(player) end

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
    for k, v in ipairs(player.all()) do
      if v:has_item_by_id(self.instance_id) then
        return v
      end
    end
  end

  --- Performs a menu action on the item on behalf of the player.
  -- Runs the 'PlayerCanUseItem' hook and then the hook of the action ('PlayerTakeItem',
  -- 'PlayerUseItem' or 'PlayerDropItem'). Every action except 'on_use' and 'on_take' also calls
  -- the item's method of the same name with the player and the extra arguments.
  -- Runs the 'PlayerUsedItem' hook when done.
  -- ```
  -- -- Makes the player pick up the item into their hotbar.
  -- item_obj:do_menu_action('on_take', player, { inv_type = 'hotbar' })
  -- ```
  -- @param act [String 'on_use', 'on_take', 'on_drop' or the callback of a custom button]
  -- @param player [Player the player performing the action]
  -- @param ... [Vararg extra arguments that are passed to the hooks and to the item's method]
  function ItemBase:do_menu_action(act, player, ...)
    if hook.run('PlayerCanUseItem', player, self, act, ...) == false then return end

    if act == 'on_take' then
      if hook.run('PlayerTakeItem', player, self, ...) != nil then return end
    end

    if act == 'on_use' then
      if hook.run('PlayerUseItem', player, self, ...) != nil then return end
    end

    if act == 'on_drop' then
      if hook.run('PlayerDropItem', player, self.instance_id) != nil then return end
    end

    if self[act] then
      if act != 'on_take' and act != 'on_use' and act != 'on_take' then
        local success, exception = pcall(self[act], self, player, ...)

        if !success then
          error_with_traceback('Item callback has failed to run! '..tostring(exception))
          return
        end
      end

      if self.action_sounds[act] then
        player:EmitSound(self.action_sounds[act])
      end
    end

    hook.run('PlayerUsedItem', player, self, act, ...)
  end

  Cable.receive('fl_items_menu_action', function(player, instance_id, action, ...)
    local item_obj = Item.find_instance_by_id(instance_id)

    if !item_obj then return end

    item_obj:do_menu_action(action, player, ...)
  end)
else
  --- Asks the server to perform a menu action on the item on behalf of the local player.
  -- @param act [String 'on_use', 'on_take', 'on_drop' or the callback of a custom button]
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
-- @return [Any the value, or the default if the value is nil or false]
function ItemBase:get_data(id, default)
  if !id then return end

  return self.data[id] or default
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
