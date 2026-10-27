--- Client side of the Areas API plugin: draws the areas of the Area Tool's selected mode,
-- shows the texts of text areas on the HUD, and receives the areas and the enter and leave
-- events from the server.

local text_area_color = Color(255, 255, 255)

do
  local cache = nil
  local temp_cache = nil
  local _render_color = Color(50, 255, 50)
  local render_color_red = Color(255, 50, 50)
  local last_amt = nil
  local last_type = nil
  local render = render
  local draw_line = render.DrawLine
  local area_colors = {}

  --- Draws wireframes of the areas that belong to the selected mode of the area tool,
  -- and the outline of the area being created, while the local player holds that tool.
  -- @param draw_depth [Boolean whether the depth pass is being drawn]
  -- @param draw_skybox [Boolean whether the skybox is being drawn]
  function Area:PostDrawOpaqueRenderables(draw_depth, draw_skybox)
    if draw_depth or draw_skybox or !IsValid(PLAYER) then return end

    local weapon = PLAYER:GetActiveWeapon()

    if IsValid(weapon) and weapon:GetClass() == 'gmod_tool' and weapon:GetMode() == 'area' then
      local tool = PLAYER:GetTool()
      local mode = tool and tool:get_area_mode()

      if !istable(mode) then return end

      local verts = tool.area and tool.area.verts
      local area_table = Areas.get_by_type(mode.area_type)
      local areas_count = #area_table

      if istable(verts) and (!temp_cache or #temp_cache != #verts) then
        temp_cache = {}

        local vert_count = #verts

        for k = 1, vert_count do
          local n

          if k == vert_count then
            n = verts[1]
          else
            n = verts[k + 1]
          end

          temp_cache[k] = { verts[k], n }
        end
      elseif !verts then
        temp_cache = nil
      end

      if !last_amt then last_amt = areas_count end

      if !cache or last_amt != areas_count or last_type != mode.area_type then
        cache = {}
        last_amt = areas_count
        last_type = mode.area_type

        area_colors[mode.area_type] = Areas.get_color(mode.area_type)

        for _, area in pairs(area_table) do
          local add = Vector(0, 0, area.maxh)

          for _, poly in ipairs(area.polys) do
            local point_count = #poly

            for idx = 1, point_count do
              local p = poly[idx]
              local n

              if idx == point_count then
                n = poly[1]
              else
                n = poly[idx + 1]
              end

              cache[#cache + 1] = { p, n, p + add, n + add }
            end
          end
        end
      end

      local area_render_color = area_colors[mode.area_type]

      if cache and areas_count > 0 then
        for i = 1, #cache do
          local v = cache[i]
          local p, ap = v[1], v[3]

          draw_line(p, v[2], area_render_color)
          draw_line(ap, v[4], area_render_color)
          draw_line(ap, p, area_render_color)
        end
      end

      if temp_cache then
        for i = 1, #temp_cache do
          local v = temp_cache[i]

          draw_line(v[1], v[2], render_color_red)
        end
      end
    end
  end
end

--- Draws the texts of the text areas the local player has recently entered,
-- fading each of them out before it expires.
function Area:HUDPaint()
  if IsValid(PLAYER) and istable(PLAYER.text_areas) then
    local last_y = math.scale(400)
    local cur_time = CurTime()
    local font

    for _, text_area in pairs(PLAYER.text_areas) do
      if istable(text_area) and text_area.end_time > cur_time then
        text_area.alpha = text_area.alpha or 255
        font = font or Theme.get_font('text_large')
        text_area_color.a = text_area.alpha

        draw.SimpleText(text_area.text, font, math.scale_x(32), last_y, text_area_color)

        if cur_time + 2 >= text_area.end_time then
          text_area.alpha = math.Clamp(text_area.alpha - 1, 0, 255)
        end

        last_y = last_y + math.scale(50)
      end
    end
  end
end

Cable.receive('fl_player_entered_area', function(area_idx, pos)
  local area = Areas.all()[area_idx]

  if !istable(area) then return end

  try(Areas.get_callback(area.type), PLAYER, area, true, pos, CurTime())
end)

Cable.receive('fl_player_left_area', function(area_idx, pos)
  local area = Areas.all()[area_idx]

  if !istable(area) then return end

  try(Areas.get_callback(area.type), PLAYER, area, false, pos, CurTime())
end)

Cable.receive('fl_areas_load', function(area_storage)
  Areas.set_stored(area_storage)
end)

Cable.receive('fl_area_remove', function(id)
  Areas.remove(id)
end)

Cable.receive('fl_area_register', function(id, data)
  Areas.register(id, data)
end)
