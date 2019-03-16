local blur_texture = Material('pp/blurscreen')
local color_white = Color(255, 255, 255)

function SurfaceText:PostDrawOpaqueRenderables()
  if !IsValid(PLAYER) then return end

  local weapon = PLAYER:GetActiveWeapon()
  local client_pos = PLAYER:GetPos()

  if IsValid(weapon) and weapon:GetClass() == 'gmod_tool' then
    local mode = weapon:GetMode()

    if mode == 'texts' then
      self:draw_text_preview()
    elseif mode == 'pictures' then
      self:draw_picture_preview()
    end
  end

  for k, v in ipairs(self.texts) do
    local pos = v.pos
    local distance = client_pos:Distance(pos)
    local fade_offset = v.fade_offset or 1000
    local draw_distance = (1024 + fade_offset)

    if distance > draw_distance then continue end

    local fade_alpha = 255
    local fade_distance = (768 + fade_offset)

    if distance > fade_distance then
      local d = distance - fade_distance
      fade_alpha = math.Clamp((255 * ((draw_distance - fade_distance) - d) / (draw_distance - fade_distance)), 0, 255)
    end

    local angle = v.angle
    local normal = v.normal
    local scale = v.scale
    local text = v.text
    local text_color = v.color
    local back_color = v.extra_color
    local style = v.style
    local w, h = util.text_size(text, Theme.get_font('text_3d2d'))
    local pos_x, pos_y = -w * 0.5, -h * 0.5

    if style >= 2 then
      cam.Start3D2D(pos + (normal * 0.4), angle, 0.1 * scale)
        if style >= 5 then
          local box_alpha = back_color.a
          local box_x, box_y = pos_x - 32, pos_y - 16

          if style == 6 then
            box_alpha = box_alpha * math.abs(math.sin(CurTime() * 3))
          end

          if style == 10 then
            render.ClearStencil()
            render.SetStencilEnable(true)
            render.SetStencilCompareFunction(STENCIL_ALWAYS)
            render.SetStencilPassOperation(STENCIL_REPLACE)
            render.SetStencilFailOperation(STENCIL_KEEP)
            render.SetStencilZFailOperation(STENCIL_KEEP)
            render.SetStencilWriteMask(254)
            render.SetStencilTestMask(254)
            render.SetStencilReferenceValue(ref or 75)

            surface.SetDrawColor(255, 255, 255, 10)
            surface.DrawRect(box_x, box_y, w + 64, h + 32)

            render.SetStencilCompareFunction(STENCIL_EQUAL)

            render.SetMaterial(blur_texture)

            for i = 0, 1, 0.3 do
              blur_texture:SetFloat('$blur', i * 8)
              blur_texture:Recompute()
              render.UpdateScreenEffectTexture()
              render.DrawScreenQuad()
            end

            render.SetStencilEnable(false)

            surface.SetDrawColor(back_color:alpha(10))
            surface.DrawRect(box_x, box_y, w + 64, h + 32)
          elseif style != 8 and style != 9 then
            draw.RoundedBox(0, box_x, pos_y - 16, w + 64, h + 32, v.extra_color:alpha(math.clamp(fade_alpha, 0, box_alpha)))
          end

          if style == 7 or style == 8 then
            local bar_color = Color(255, 255, 255, math.Clamp(fade_alpha, 0, box_alpha))

            draw.RoundedBox(0, box_x, box_y, w + 64, 6, bar_color)
            draw.RoundedBox(0, box_x, box_y + h + 26, w + 64, 6, bar_color)
          elseif style == 9 then
            local tall, wide = 6, w + 64
            local rect_width = (wide / 3 - wide / 6) * 0.75
            local bar_color = Color(255, 255, 255, math.Clamp(fade_alpha, 0, box_alpha))

            -- Draw left thick rectangles
            draw.RoundedBox(0, box_x, box_y - 6, rect_width, 10, bar_color)
            draw.RoundedBox(0, box_x, box_y + h + 22, rect_width, 10, bar_color)

            -- ...and the right ones
            draw.RoundedBox(0, box_x + wide - rect_width, box_y - 6, rect_width, 10, bar_color)
            draw.RoundedBox(0, box_x + wide - rect_width, box_y + h + 22, rect_width, 10, bar_color)

            -- And the middle thingies
            draw.RoundedBox(0, -(wide / 1.75) * 0.5, box_y, wide / 1.75, 4, bar_color)
            draw.RoundedBox(0, -(wide / 1.75) * 0.5, box_y + h + 22, wide / 1.75, 4, bar_color)
          end
        end

        if style != 3 then
          draw.SimpleText(text, Theme.get_font('text_3d2d'), pos_x, pos_y, text_color:alpha(math.clamp(fade_alpha, 0, 100)):darken(30))
        end
      cam.End3D2D()
    end

    if style >= 3 then
      cam.Start3D2D(pos + (normal * 0.95 * (scale + 0.5)), angle, 0.1 * scale)
        draw.SimpleText(text, Theme.get_font('text_3d2d'), pos_x, pos_y, Color(0, 0, 0, math.Clamp(fade_alpha, 0, 240)))
      cam.End3D2D()
    end

    cam.Start3D2D(pos + (normal * 1.25 * (scale + 0.5)), angle, 0.1 * scale)
      draw.SimpleText(text, Theme.get_font('text_3d2d'), pos_x, pos_y, text_color:alpha(fade_alpha))
    cam.End3D2D()
  end

  for k, v in ipairs(self.pictures) do
    local pos = v.pos
    local distance = client_pos:Distance(pos)
    local fade_offset = v.fade_offset or 1000
    local draw_distance = 1024 + fade_offset

    if distance > draw_distance then continue end

    local fade_alpha = 255
    local fade_distance = 768 + fade_offset

    if distance > fade_distance then
      local d = distance - fade_distance
      fade_alpha = math.Clamp((255 * ((draw_distance - fade_distance) - d) / (draw_distance - fade_distance)), 0, 255)
    end

    local height = v.height
    local width = v.width

    cam.Start3D2D(pos + (v.normal * 0.4), v.angle, 0.1)
      draw.textured_rect(URLMaterial(v.url), -width * 0.5, -height * 0.5, width, height, color_white:alpha(fade_alpha))
    cam.End3D2D()
  end
end

function SurfaceText:draw_text_preview()
  local tool = PLAYER:GetTool()
  local text = tool:GetClientInfo('text')
  local style = tool:GetClientNumber('style')
  local trace = PLAYER:GetEyeTrace()
  local normal = trace.HitNormal
  local w, h = util.text_size(text, Theme.get_font('text_3d2d'))
  local angle = normal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  cam.Start3D2D(trace.HitPos + (normal * 1.25), angle, 0.1 * tool:GetClientNumber('scale'))
    if style >= 5 then
      if style != 8 and style != 9 then
        draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 - 16, w + 64, h + 32, Color(tool:GetClientNumber('r2', 0), tool:GetClientNumber('g2', 0), tool:GetClientNumber('b2', 0), 40))
      end

      if style == 7 or style == 8 then
        draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 - 16, w + 64, 6, Color(255, 255, 255, 40))
        draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 + h + 10, w + 64, 6, Color(255, 255, 255, 40))
      elseif style == 9 then
        local wide = w + 64
        local bar_color = Color(255, 255, 255, 40)
        local bar_x, bar_y = -w * 0.5 - 32, -h * 0.5 - 16
        local rect_width = (wide / 3 - wide / 6) * 0.75

        -- Draw left thick rectangles
        draw.RoundedBox(0, bar_x, bar_y - 6, rect_width, 10, bar_color)
        draw.RoundedBox(0, bar_x, bar_y + h + 22, rect_width, 10, bar_color)

        -- ...and the right ones
        draw.RoundedBox(0, bar_x + wide - rect_width, bar_y - 6, rect_width, 10, bar_color)
        draw.RoundedBox(0, bar_x + wide - rect_width, bar_y + h + 22, rect_width, 10, bar_color)

        -- And the middle thingies
        draw.RoundedBox(0, -(wide / 1.75) * 0.5, bar_y, wide / 1.75, 4, bar_color)
        draw.RoundedBox(0, -(wide / 1.75) * 0.5, bar_y + h + 22, wide / 1.75, 4, bar_color)
      end
    end

    draw.SimpleText(text, Theme.get_font('text_3d2d'), -w * 0.5, -h * 0.5, Color(tool:GetClientNumber('r', 0), tool:GetClientNumber('g', 0), tool:GetClientNumber('b', 0), 60))
  cam.End3D2D()
end

function SurfaceText:draw_picture_preview()
  local tool = PLAYER:GetTool()
  local url = tool:GetClientInfo('url')
  local width = tool:GetClientNumber('width')
  local height = tool:GetClientNumber('height')
  local trace = PLAYER:GetEyeTrace()
  local normal = trace.HitNormal
  local angle = normal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  cam.Start3D2D(trace.HitPos + (normal * 1.25), angle, 0.1)
    if url:ends('.png') or url:ends('.jpg') or url:ends('.jpeg') then
      draw.textured_rect(URLMaterial(url), -width * 0.5, -height * 0.5, width, height, color_white)
    else
      draw.RoundedBox(0, -width * 0.5, -height * 0.5, width, height, Color(255, 0, 0, 40))
    end
  cam.End3D2D()
end
