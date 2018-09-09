class 'Item'

function Item:init(id)
  if !isstring(id) then return end

  self.id = string.to_id(id)
  self.data = self.data or {}
  self.action_sounds = {
    ["on_use"] = "items/battery_pickup.wav"
  }
end

function Item:get_name()
  return self.print_name or self.name
end

Item.name = Item.get_name

function Item:set_base(base_class)
  if isstring(base_class) then
    base_class = _G[base_class]
  end

  if !istable(base_class) then return end

  ITEM = nil
  ITEM = base_class.new(self.id)
end

function Item:make_base()
  pipeline.Abort()
end

function Item:get_real_name()
  return self.name or "Unknown Item"
end

function Item:get_description()
  return self.description or "This item has no description!"
end

function Item:get_weight()
  return self.weight or 1
end

function Item:get_max_stack()
  return self.max_stack or 64
end

function Item:GetModel()
  return self.model or "models/props_lab/cactus.mdl"
end

function Item:GetSkin()
  return self.skin or 0
end

function Item:GetColor()
  return self.color or Color(255, 255, 255)
end

function Item:add_button(name, data)
  --[[
    Example data structure:
    data = {
      icon = "path/to/icon.png",
      callback = "on_use", -- This will call ITEM:on_use function when the button is pressed.
      onShow = function(item_table) -- Client-Side function. Determines whether the button will be shown.
        return true
      end
    }
  --]]

  if !self.custom_buttons then
    self.custom_buttons = {}
  end

  self.custom_buttons[name] = data
end

function Item:set_action_sound(act, sound)
  self.action_sounds[act] = sound
end

-- Returns:
-- nothing/nil = drop like normal
-- false = prevents item appearing and doesn't remove it from inventory.
function Item:on_drop(player) end

function Item:on_loadout(player) end

function Item:on_save(player) end

if SERVER then
  function Item:set_data(id, value)
    if !id then return end

    self.data[id] = value

    item.NetworkItemData(self:get_player(), self)
  end

  function Item:get_player()
    for k, v in ipairs(player.GetAll()) do
      if v:HasItemByID(self.instance_id) then
        return v
      end
    end
  end

  function Item:do_menu_action(act, player, ...)
    if act == "on_take" then
      if hook.run("PlayerTakeItem", player, self, ...) != nil then return end
    end

    if act == "on_use" then
      if hook.run("PlayerUseItem", player, self, ...) != nil then return end
    end

    if act == "on_drop" then
      if hook.run("PlayerDropItem", player, self.instance_id) != nil then return end
    end

    if self[act] then
      if act != "on_take" and act != "on_use" and act != "on_take" then
        try {
          self[act], self, player, ...
        } catch {
          function(exception)
            ErrorNoHalt("Item callback has failed to run! "..tostring(exception).."\n")
          end
        }

        if !SUCCEEDED then return end
      end

      if self.action_sounds[act] then
        player:EmitSound(self.action_sounds[act])
      end
    end

    if act == "on_take" then
      if hook.run("PlayerTakenItem", player, self, ...) != nil then return end
    end

    if act == "on_use" then
      if hook.run("PlayerUsedItem", player, self, ...) != nil then return end
    end

    if act == "on_drop" then
      if hook.run("PlayerDroppedItem", player, self.instance_id, self, ...) != nil then return end
    end
  end

  netstream.Hook("ItemMenuAction", function(player, instance_id, action, ...)
    local item_table = item.FindInstanceByID(instance_id)

    if !item_table then return end
    if hook.run("PlayerCanUseItem", player, item_table, action, ...) == false then return end

    item_table:do_menu_action(action, player, ...)
  end)
else
  function Item:do_menu_action(act, ...)
    netstream.Start("ItemMenuAction", self.instance_id, act, ...)
  end

  function Item:get_use_text()
    return self.use_text or t('item.option.use')
  end

  function Item:get_take_text()
    return self.take_text or t('item.option.take')
  end

  function Item:get_drop_text()
    return self.DropText or t('item.option.drop')
  end

  function Item:get_cancel_text()
    return self.cancel_text or t('item.option.cancel')
  end
end

function Item:get_data(id, default)
  if !id then return end

  return self.data[id] or default
end

function Item:set_entity(ent)
  self.entity = ent
end

function Item:register()
  return item.register(self.id, self)
end

-- Fancy output if you do print(item_table).
function Item:__tostring()
  return "Item ["..tostring(self.instance_id).."]["..(self.name or self.id).."]"
end
