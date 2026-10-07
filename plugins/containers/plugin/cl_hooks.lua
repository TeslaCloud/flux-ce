--- Draws the name and the description of the container that the local player is looking at.
-- @param entity [Entity]
-- @param x [Number screen position]
-- @param y [Number screen position]
-- @param dist [Number distance between the local player and the entity]
function Container:DrawEntityTargetID(entity, x, y, dist)
  if dist < 300 then
    local container_data = self:find(entity:GetModel())

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

--- Prevents opening the menu of items that are stored inside of containers.
-- @param item_obj [Item]
-- @return [Boolean false to prevent the menu from opening, nil otherwise]
function Container:CanItemMenuOpen(item_obj)
  if item_obj.inventory_type == 'container' then
    return false
  end
end

--- Returns the translated name of the container.
-- @param entity [Entity]
-- @return [String name, or nil if the entity is not a container]
function Container:GetEntityName(entity)
  local container_data = self:find(entity:GetModel())

  if container_data then
    return t(container_data.name)
  end
end

--- Adds the 'open' option to the interactions menu of the container props.
-- @param menu [Panel the interactions menu]
-- @param entity [Entity]
function Container:CreateEntityInteractions(menu, entity)
  local container_data = self:find(entity:GetModel())
  
  if container_data and entity:GetClass() == 'prop_physics' then
    menu:AddOption(t'ui.container.open', function()
      Cable.send('fl_container_open', entity)
    end):SetIcon('icon16/box.png')
  end
end
