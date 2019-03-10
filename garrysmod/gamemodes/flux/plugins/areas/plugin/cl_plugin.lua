do
  local cache = nil
  local temp_cache = nil
  local render_color = Color(50, 255, 50)
  local render_color_red = Color(255, 50, 50)
  local last_amt = nil
  local render = render
  local area_colors = {}

  function Area:PostDrawOpaqueRenderables(draw_depth, draw_skybox)
    if draw_depth or draw_skybox then return end

    local weapon = Flux.client:GetActiveWeapon()

    if IsValid(weapon) and weapon:GetClass() == 'gmod_tool' and weapon:GetMode() == 'area' then
      local tool = Flux.client:GetTool()
      local mode = tool:GetAreaMode()
      local verts = (tool and tool.area and tool.area.verts)
      local area_table = areas.get_by_type(mode.area_type)
      local areas_count = #area_table

      if istable(verts) and (!temp_cache or #temp_cache != #verts) then
        temp_cache = {}

        for k, v in ipairs(verts) do
          local n

          if k == #verts then
            n = verts[1]
          else
            n = verts[k + 1]
          end

          table.insert(temp_cache, {v, n})
        end
      elseif !verts then
        temp_cache = nil
      end

      if !last_amt then last_amt = areas_count end

      if !cache or last_amt != areas_count then
        cache = {}

        area_colors[mode.area_type] = areas.get_color(mode.area_type)

        for k, v in pairs(area_table) do
          for k2, v2 in ipairs(v.polys) do
            for idx, p in ipairs(v2) do
              local n

              if idx == #v2 then
                n = v2[1]
              else
                n = v2[idx + 1]
              end

              local add = Vector(0, 0, v.maxh)

              table.insert(cache, { p, n, p + add, n + add })
            end
          end
        end
      end

      local area_render_color = area_colors[mode.area_type]

      if cache then
        for k, v in ipairs(cache) do
          local p, ap = v[1], v[3]

          render.DrawLine(p, v[2], area_render_color)
          render.DrawLine(ap, v[4], area_render_color)
          render.DrawLine(ap, p, area_render_color)
        end
      end

      if temp_cache then
        for k, v in ipairs(temp_cache) do
          render.DrawLine(v[1], v[2], render_color_red)
        end
      end
    end
  end
end

function Area:HUDPaint()
  if istable(Flux.client.text_areas) then
    local last_y = 400
    local cur_time = CurTime()

    for k, v in pairs(Flux.client.text_areas) do
      if istable(v) and v.end_time > cur_time then
        v.alpha = v.alpha or 255

        draw.SimpleText(v.text, Theme.get_font('text_large'), 32, last_y, Color(255, 255, 255, v.alpha))

        if cur_time + 2 >= v.end_time then
          v.alpha = math.Clamp(v.alpha - 1, 0, 255)
        end

        last_y = last_y + 50
      end
    end
  end
end

cable.receive('fl_player_entered_area', function(area_idx, idx, pos)
  local area = areas.all()[area_idx]

  Try('Areas', areas.get_callback(area.type), Flux.client, area, true, pos, CurTime())
end)

cable.receive('fl_player_left_area', function(area_idx, idx, pos)
  local area = areas.all()[area_idx]

  Try('Areas', areas.get_callback(area.type), Flux.client, area, false, pos, CurTime())
end)

cable.receive('fl_areas_load', function(area_storage)
  areas.set_stored(area_storage)
end)

cable.receive('fl_area_remove', function(id)
  areas.remove(id)
end)

cable.receive('fl_area_register', function(id, data)
  areas.register(id, data)
end)
