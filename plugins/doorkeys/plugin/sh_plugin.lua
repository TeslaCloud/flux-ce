--- Door Keys adds keys that belong to doors. Staff with the 'manage_doors' permission create
-- a key for a door, add existing keys to it, list its keys and take them off it from the keys
-- property of the door menu. A player with a key molding kit uses up a key blank to copy one of
-- their keys. Holding a key lets a player lock and unlock every door it belongs to.
-- `OnKeyCopy` lets plugins change the copy of a key before the player receives it.

require_relative 'sv_hooks'

local function key_select(entity)
  local keys = PLAYER:find_items('key')

  local selector = vgui.Create('fl_selector')
  selector:set_title(t'ui.key.add.title')
  selector:set_text(t'ui.key.add.message')
  selector:set_value(t'ui.key.add.select')

  if keys then
    for _, key_item in pairs(keys) do
      selector:add_choice('['..key_item.instance_id..'] '..t(key_item:get_name()), function()
        Cable.send('fl_key_add', key_item.instance_id, entity)
      end)
    end
  end
end

Item.set_category_icon('item.category.keys', 'icon16/key.png')

--- Registers the keys door property, which saves the door's keys and adds a menu to list, create and add keys.
function PLUGIN:RegisterDoorProperties()
  Doors:register_property('keys', {
    get_save_data = entity -> entity:get_nv('fl_keys', {}),
    on_load = function(entity, data)
      entity:set_nv('fl_keys', data)
    end,
    create_panel = function(entity, panel)
      local keys_list = panel.properties:CreateRow(t'door.categories.general', t'door.properties.keys_list.name')
      keys_list:Setup('Combo', { text = t'door.properties.keys_list.select' })

      keys_list:AddChoice(t'door.properties.keys_list.show', function()
        Cable.send('fl_key_show_list', entity)
      end)

      keys_list:AddChoice(t'door.properties.keys_list.create', function()
        Cable.send('fl_key_create', entity)
      end)

      keys_list:AddChoice(t'door.properties.keys_list.add', function()
        key_select(entity)
      end)

      keys_list.DataChanged = function(_pnl, callback)
        if callback then
          callback()
        end
      end
    end
  })
end

if CLIENT then
  local line_color = Color(0, 0, 0, 100)

  Cable.receive('fl_key_show_list', function(keys, entity)
    local frame = vgui.Create('DFrame')
    frame:SetSize(math.scale(300), math.scale(300))
    frame:Center()
    frame:MakePopup()
    frame:SetTitle(t'ui.key.title')

    local list = vgui.Create('DScrollPanel', frame)
    list:Dock(FILL)

    --- Refills the list with the door's keys, each with a delete button, followed by a button to add a key.
    function frame:rebuild()
      list:Clear()

      if keys then
        for _, instance_id in pairs(keys) do
          local item_table = Item.find_instance_by_id(instance_id)

          local line = vgui.Create('fl_base_panel')
          line:Dock(TOP)
          line.Paint = function(_pnl, w, h)
            draw.RoundedBox(0, 0, 0, w, h, line_color)
          end

          local button_size = line:GetTall() - 4

          local delete = vgui.Create('fl_button', line)
          delete:SetSize(button_size, button_size)
          delete:SetDrawBackground(false)
          delete:SetTooltip(t'ui.key.delete.title')
          delete:set_icon('fa-trash')
          delete:set_icon_size(button_size)
          delete:Dock(RIGHT)
          delete.DoClick = function(_btn)
            Derma_Query(t'ui.key.delete.message',
            t'ui.key.delete.title',
            t'ui.yes',
            function()
              Cable.send('fl_key_remove', instance_id, entity)

              table.RemoveByValue(keys, instance_id)

              frame:rebuild()
            end, t'ui.no')
          end

          local label = vgui.Create('DLabel', line)
          label:SetText('['..item_table.instance_id..']'..t(item_table:get_name()))
          label:SetFont(Theme.get_font('main_menu_normal'))
          label:SetTextColor(color_white)
          label:SetContentAlignment(4)
          label:SizeToContents()
          label:DockMargin(2, 0, 0, 0)
          label:Dock(FILL)

          list:Add(line)
        end
      end

      local add_button = vgui.Create('DButton')
      add_button:SetText(t'door.properties.keys_list.add')
      add_button:Dock(TOP)
      add_button.DoClick = function(_btn)
        key_select(entity)
      end

      list:Add(add_button)
    end

    frame:rebuild()
  end)

  Cable.receive('fl_key_copy', function(_instance_id)
    local keys = PLAYER:find_items('key')

    local selector = vgui.Create('fl_selector')
    selector:set_title(t'ui.key.copy.title')
    selector:set_text(t'ui.key.copy.message')
    selector:set_value(t'ui.key.copy.select')

    if keys then
      for _, key_item in pairs(keys) do
        selector:add_choice('['..key_item.instance_id..']'..t(key_item:get_name()), function()
          Cable.send('fl_key_copy', key_item.instance_id)
        end)
      end
    end
  end)
end
