function Container:DrawEntityTargetID(entity, x, y, dist)
  if dist < 300 then
    local container_data = Container:all()[entity:GetModel()]

    if container_data then
      local title = t(container_data.name)
      local alpha = 255 - 255 * (dist / 300)

      if title then
        local font = Theme.get_font('tooltip_large')
        local text_w, text_h = util.text_size(title, font)

        draw.SimpleTextOutlined(title, font, x - text_w * 0.5, y, Theme.get_color('accent_light'):alpha(alpha), nil, nil, 1, color_black:alpha(alpha))

        y = y + text_h + 4
      end

      local desc = t(container_data.desc)

      if desc then
        local font = Theme.get_font('tooltip_normal')
        local text_w, text_h = util.text_size(desc, font)

        draw.SimpleTextOutlined(desc, font, x - text_w * 0.5, y, color_white:alpha(alpha), nil, nil, 1, color_black:alpha(alpha))
      end
    end
  end
end

function Container:CanItemMenuOpen(item_table)
  if item_table.inventory_type == 'container' then
    return false
  end
end

function Container:OnInventoryRefresh(inv_type, old_inv_type)
  if IsValid(Flux.container) then
    Flux.container:rebuild()
  end
end

function Container:CanItemMove(instance_ids, inventory_panel, receiver)
  if inventory_panel.inventory_type == 'container' then return false end

  local item_table = Item.find_instance_by_id(instance_ids[1])

  if item_table and item_table.inventory_type == 'container' then
    return false
  end
end

function Container:OnItemMove(instance_ids, inventory_panel, receiver)
  local item_table = Item.find_instance_by_id(instance_ids[1])

  if IsValid(inventory_panel.entity) or item_table and item_table.inventory_type == 'container' then
    Cable.send('fl_item_container_move', instance_ids, inventory_panel.inventory_type, receiver.inv_x, receiver.inv_y, 
    inventory_panel.entity or item_table.inventory_entity)
  end
end

Cable.receive('fl_open_container', function(entity)
  Flux.container = vgui.create('fl_container')
  Flux.container:set_target_entity(entity)
  Flux.container:rebuild()
end)

Cable.receive('fl_close_container', function(entity)
  if IsValid(Flux.container) then
    Flux.container:safe_remove()
  end
end)
