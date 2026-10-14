require_relative 'sv_hooks'

local function KeySelect(entity)
  local keys = PLAYER:find_items('key')

  local selector = vgui.Create('fl_selector')
  selector:set_title(t'ui.key.add.title')
  selector:set_text(t'ui.key.add.message')
  selector:set_value(t'ui.key.add.select')

  if keys then
    for k, v in pairs(keys) do
      selector:add_choice('['..v.instance_id..'] '..t(v:get_name()), function()
        Cable.send('fl_key_add', v.instance_id, entity)
      end)
    end
  end
end

Item.set_category_icon('item.category.keys', 'icon16/key.png')

--- Registers the keys door property, which saves the door's keys and adds a menu to list, create and add keys.
function PLUGIN:RegisterDoorProperties()
  Doors:register_property('keys', {
    get_save_data = function(entity)
      return entity:get_nv('fl_keys', {})
    end,
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
        KeySelect(entity)
      end)

      keys_list.DataChanged = function(pnl, callback)
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
        for k, v in pairs(keys) do
          local item_table = Item.find_instance_by_id(v)

          local line = vgui.Create('fl_base_panel')
          line:Dock(TOP)
          line.Paint = function(pnl, w, h)
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
          delete.DoClick = function(btn)
            Derma_Query(t'ui.key.delete.message',
            t'ui.key.delete.title',
            t'ui.yes',
            function()
              Cable.send('fl_key_remove', v, entity)

              table.RemoveByValue(keys, v)

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
      add_button.DoClick = function(btn)
        KeySelect(entity)
      end

      list:Add(add_button)
    end

    frame:rebuild()
  end)

  Cable.receive('fl_key_copy', function(instance_id)
    local keys = PLAYER:find_items('key')

    local selector = vgui.Create('fl_selector')
    selector:set_title(t'ui.key.copy.title')
    selector:set_text(t'ui.key.copy.message')
    selector:set_value(t'ui.key.copy.select')

    if keys then
      for k, v in pairs(keys) do
        selector:add_choice('['..v.instance_id..']'..t(v:get_name()), function()
          Cable.send('fl_key_copy', v.instance_id)
        end)
      end
    end
  end)
end
