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

function Container:CanItemMenuOpen(item_table)
  if item_table.inventory_type == 'container' then
    return false
  end
end
