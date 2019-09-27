class 'ItemBase'

function ItemBase:init(id)
  if !isstring(id) then return end

  self.id = string.to_id(id)
  self.data = self.data or {}
  self.bases = self.bases or {}
  self.base_count = 0
end

-- Fancy output if you do print(item_table).
function ItemBase:__tostring()
  return '#<Item:'..(self.name or self.id)..' '..tostring(self.instance_id)..'>'
end

function ItemBase:get_name()
  return self.print_name or self.name
end

ItemBase.name = ItemBase.get_name

function ItemBase:base_off(what)
  if isstring(what) then
    what = what:capitalize()
  end

  local module_table = isstring(what) and (what:parse_table() or ('Item'..what):parse_table()) or what

  if !istable(module_table) then return end

  for k, v in pairs(module_table) do
    if !self[k] then
      self[k] = v
    end
  end

  self.bases[module_table.class_name] = module_table

  if isstring(what) then
    self.bases[what] = module_table
  end

  self.base_count = self.base_count + 1
end

function ItemBase:is(base)
  if isstring(base) then
    base = base:capitalize()
    return self.bases[base] or self.bases['Item'..base]
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

function ItemBase:get_real_name()
  return self.name or 'Unknown Item'
end

function ItemBase:get_description()
  return self.description or 'This item has no description!'
end

function ItemBase:get_weight()
  return self.weight or 1
end

function ItemBase:get_max_stack()
  return self.max_stack or 64
end

function ItemBase:get_model()
  return self.model or 'models/props_lab/cactus.mdl'
end

function ItemBase:get_skin()
  return self.skin or 0
end

function ItemBase:get_color()
  return self.color or Color(255, 255, 255)
end

function ItemBase:add_button(name, data)
  --[[
    Example data structure:
    data = {
      icon = 'path/to/icon.png',
      callback = 'on_use', -- This will call ITEM:on_use function when the button is pressed.
      on_show = function(item_table) -- Client-Side function. Determines whether the button will be shown.
        return true
      end
    }
  --]]

  if !self.custom_buttons then
    self.custom_buttons = {}
  end

  self.custom_buttons[name] = data
end

function ItemBase:set_action_sound(act, sound)
  self.action_sounds[act] = sound
end

-- Returns:
-- nothing/nil = drop like normal
-- false = prevents item appearing and doesn't remove it from inventory.
function ItemBase:on_drop(player) end

function ItemBase:on_loadout(player) end

function ItemBase:on_save(player) end

if SERVER then
  function ItemBase:set_data(id, value)
    if !id then return end

    self.data[id] = value

    Item.network_item_data(self:get_player(), self)
  end

  function ItemBase:get_player()
    for k, v in ipairs(player.all()) do
      if v:has_item_by_id(self.instance_id) then
        return v
      end
    end
  end

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
        try {
          self[act], self, player, ...
        } catch {
          function(exception)
            error_with_traceback('Item callback has failed to run! '..tostring(exception))
          end
        }

        if !SUCCEEDED then return end
      end

      if self.action_sounds[act] then
        player:EmitSound(self.action_sounds[act])
      end
    end

    if act == 'on_take' then
      if hook.run('PlayerTakenItem', player, self, ...) != nil then return end
    end

    if act == 'on_use' then
      if hook.run('PlayerUsedItem', player, self, ...) != nil then return end
    end

    if act == 'on_drop' then
      if hook.run('PlayerDroppedItem', player, self.instance_id, self, ...) != nil then return end
    end
  end

  Cable.receive('fl_items_menu_action', function(player, instance_id, action, ...)
    local item_table = Item.find_instance_by_id(instance_id)

    if !item_table then return end

    item_table:do_menu_action(action, player, ...)
  end)
else
  function ItemBase:do_menu_action(act, ...)
    Cable.send('fl_items_menu_action', self.instance_id, act, ...)
  end

  function ItemBase:get_use_text()
    return self.use_text or 'item.option.use'
  end

  function ItemBase:get_take_text()
    return self.take_text or 'item.option.take'
  end

  function ItemBase:get_drop_text()
    return self.drop_text or 'item.option.drop'
  end

  function ItemBase:get_cancel_text()
    return self.cancel_text or 'item.option.cancel'
  end

  function ItemBase:get_icon_model()
    return self.icon_model
  end
end

function ItemBase:get_data(id, default)
  if !id then return end

  return self.data[id] or default
end

function ItemBase:set_entity(ent)
  self.entity = ent
end

function ItemBase:register()
  return Item.register(self.id, self)
end
