class "Item"

function Item:Item(id)
  if (!isstring(id)) then return end

  self.id = string.to_id(id)
  self.data = self.data or {}
  self.actionSounds = {
    ["OnUse"] = "items/battery_pickup.wav"
  }
end

function Item:get_name()
  return self.print_name or self.name
end

Item.name = Item.get_name

function Item:set_base(base_class)
  if (isstring(base_class)) then
    base_class = _G[base_class]
  end

  if (!istable(base_class)) then return end

  ITEM = nil
  ITEM = base_class(self.id)
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
      callback = "OnUse", -- This will call ITEM:OnUse function when the button is pressed.
      onShow = function(itemTable) -- Client-Side function. Determines whether the button will be shown.
        return true
      end
    }
  --]]

  if (!self.customButtons) then
    self.customButtons = {}
  end

  self.customButtons[name] = data
end

function Item:set_action_sound(act, sound)
  self.actionSounds[act] = sound
end

-- Returns:
-- nothing/nil = drop like normal
-- false = prevents item appearing and doesn't remove it from inventory.
function Item:on_drop(player) end

function Item:on_loadout(player) end

function Item:on_save(player) end

if SERVER then
  function Item:set_data(id, value)
    if (!id) then return end

    self.data[id] = value

    item.NetworkItemData(self:get_player(), self)
  end

  function Item:get_player()
    for k, v in ipairs(player.GetAll()) do
      if (v:HasItemByID(self.instanceID)) then
        return v
      end
    end
  end

  function Item:do_menu_action(act, player, ...)
    if (act == "OnTake") then
      if (hook.Run("PlayerTakeItem", player, self, ...) != nil) then return end
    end

    if (act == "OnUse") then
      if (hook.Run("PlayerUseItem", player, self, ...) != nil) then return end
    end

    if (act == "OnDrop") then
      if (hook.Run("PlayerDropItem", player, self.instanceID) != nil) then return end
    end

    if (self[act]) then
      if (act != "OnTake" and act != "OnUse" and act != "OnTake") then
        try {
          self[act], self, player, ...
        } catch {
          function(exception)
            ErrorNoHalt("Item callback has failed to run! "..tostring(exception).."\n")
          end
        }

        if (!SUCCEEDED) then return end
      end

      if (self.actionSounds[act]) then
        player:EmitSound(self.actionSounds[act])
      end
    end

    if (act == "OnTake") then
      if (hook.Run("PlayerTakenItem", player, self, ...) != nil) then return end
    end

    if (act == "OnUse") then
      if (hook.Run("PlayerUsedItem", player, self, ...) != nil) then return end
    end

    if (act == "OnDrop") then
      if (hook.Run("PlayerDroppedItem", player, self.instanceID, self, ...) != nil) then return end
    end
  end

  netstream.Hook("ItemMenuAction", function(player, instanceID, action, ...)
    local itemTable = item.FindInstanceByID(instanceID)

    if (!itemTable) then return end
    if (hook.Run("PlayerCanUseItem", player, itemTable, action, ...) == false) then return end

    itemTable:do_menu_action(action, player, ...)
  end)
else
  function Item:do_menu_action(act, ...)
    netstream.Start("ItemMenuAction", self.instanceID, act, ...)
  end

  function Item:get_use_text()
    return self.use_text or "#Item_Option_Use"
  end

  function Item:get_take_text()
    return self.TakeText or "#Item_Option_Take"
  end

  function Item:get_drop_text()
    return self.DropText or "#Item_Option_Drop"
  end

  function Item:get_cancel_text()
    return self.CancelText or "#Item_Option_Cancel"
  end
end

function Item:get_data(id, default)
  if (!id) then return end

  return self.data[id] or default
end

function Item:set_entity(ent)
  self.entity = ent
end

function Item:register()
  return item.register(self.id, self)
end

-- Fancy output if you do print(itemTable).
function Item:__tostring()
  return "Item ["..tostring(self.instanceID).."]["..(self.name or self.id).."]"
end
