--- Client side of the 3D Texts plugin: draws the placed texts and pictures in the world, and
-- the placement preview of the Text Tool and the Picture Placer.

local blur_texture = Material('pp/blurscreen')
local color_white = Color(255, 255, 255)
local Color = Color
local ColorAlpha = ColorAlpha
local clamp = math.Clamp
local sqrt = math.sqrt
local start_3d2d = cam.Start3D2D
local end_3d2d = cam.End3D2D
local rounded_box = draw.RoundedBox
local simple_text = draw.SimpleText
local fade_scale = 255 / 256

--- Draws every placed 3D text and picture within fade range of the local player,
-- plus a placement preview while the texts or pictures tool is equipped.
function SurfaceText:PostDrawOpaqueRenderables()
  local client = PLAYER

  if !IsValid(client) then return end

  local weapon = client:GetActiveWeapon()
  local client_pos = client:GetPos()

  if IsValid(weapon) and weapon:GetClass() == 'gmod_tool' then
    local mode = weapon:GetMode()

    if mode == 'texts' then
      self:draw_text_preview()
    elseif mode == 'pictures' then
      self:draw_picture_preview()
    end
  end

  local texts = self.texts
  local font = Theme.get_font('text_3d2d')

  for i = 1, #texts do
    local v = texts[i]
    local pos = v.pos
    local dist_sqr = client_pos:DistToSqr(pos)
    local fade_offset = v.fade_offset or 1000
    local draw_distance = 1024 + fade_offset

    if draw_distance < 0 or dist_sqr > draw_distance * draw_distance then continue end

    local distance = sqrt(dist_sqr)
    local fade_alpha = 255

    if distance > 768 + fade_offset then
      fade_alpha = clamp((draw_distance - distance) * fade_scale, 0, 255)
    end

    local angle = v.angle
    local normal = v.normal
    local scale = v.scale
    local text = v.text
    local text_color = v.color
    local back_color = v.extra_color
    local style = v.style
    local text_scale = 0.1 * scale
    local w, h = util.text_size(text, font)
    local pos_x, pos_y = -w * 0.5, -h * 0.5

    if style >= 2 then
      start_3d2d(pos + (normal * 0.4), angle, text_scale)
        if style >= 5 then
          local box_alpha = back_color.a
          local box_x, box_y = pos_x - 32, pos_y - 16
          local box_w = w + 64

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
            surface.DrawRect(box_x, box_y, box_w, h + 32)

            render.SetStencilCompareFunction(STENCIL_EQUAL)

            render.SetMaterial(blur_texture)

            for j = 0, 1, 0.3 do
              blur_texture:SetFloat('$blur', j * 8)
              blur_texture:Recompute()
              render.UpdateScreenEffectTexture()
              render.DrawScreenQuad()
            end

            render.SetStencilEnable(false)

            surface.SetDrawColor(ColorAlpha(back_color, 10))
            surface.DrawRect(box_x, box_y, box_w, h + 32)
          elseif style != 8 and style != 9 then
            rounded_box(0, box_x, box_y, box_w, h + 32, ColorAlpha(back_color, clamp(fade_alpha, 0, box_alpha)))
          end

          if style == 7 or style == 8 then
            local bar_color = Color(255, 255, 255, clamp(fade_alpha, 0, box_alpha))

            rounded_box(0, box_x, box_y, box_w, 6, bar_color)
            rounded_box(0, box_x, box_y + h + 26, box_w, 6, bar_color)
          elseif style == 9 then
            local rect_width = (box_w / 3 - box_w / 6) * 0.75
            local middle_width = box_w / 1.75
            local middle_x = -middle_width * 0.5
            local bar_color = Color(255, 255, 255, clamp(fade_alpha, 0, box_alpha))

            -- Draw left thick rectangles
            rounded_box(0, box_x, box_y - 6, rect_width, 10, bar_color)
            rounded_box(0, box_x, box_y + h + 22, rect_width, 10, bar_color)

            -- ...and the right ones
            rounded_box(0, box_x + box_w - rect_width, box_y - 6, rect_width, 10, bar_color)
            rounded_box(0, box_x + box_w - rect_width, box_y + h + 22, rect_width, 10, bar_color)

            -- And the middle thingies
            rounded_box(0, middle_x, box_y, middle_width, 4, bar_color)
            rounded_box(0, middle_x, box_y + h + 22, middle_width, 4, bar_color)
          end
        end

        if style != 3 then
          simple_text(text, font, pos_x, pos_y, ColorAlpha(text_color, clamp(fade_alpha, 0, 100)):darken(30))
        end
      end_3d2d()
    end

    if style >= 3 then
      start_3d2d(pos + (normal * 0.95 * (scale + 0.5)), angle, text_scale)
        simple_text(text, font, pos_x, pos_y, Color(0, 0, 0, clamp(fade_alpha, 0, 240)))
      end_3d2d()
    end

    start_3d2d(pos + (normal * 1.25 * (scale + 0.5)), angle, text_scale)
      simple_text(text, font, pos_x, pos_y, ColorAlpha(text_color, fade_alpha))
    end_3d2d()
  end

  local pictures = self.pictures

  for i = 1, #pictures do
    local v = pictures[i]
    local pos = v.pos
    local dist_sqr = client_pos:DistToSqr(pos)
    local fade_offset = v.fade_offset or 1000
    local draw_distance = 1024 + fade_offset

    if draw_distance < 0 or dist_sqr > draw_distance * draw_distance then continue end

    local distance = sqrt(dist_sqr)
    local fade_alpha = 255

    if distance > 768 + fade_offset then
      fade_alpha = clamp((draw_distance - distance) * fade_scale, 0, 255)
    end

    local height = v.height
    local width = v.width

    start_3d2d(pos + (v.normal * 0.4), v.angle, 0.1)
      draw.textured_rect(URLMaterial(v.url), -width * 0.5, -height * 0.5, width, height, color_white:alpha(fade_alpha))
    end_3d2d()
  end
end

--- Draws a translucent preview of the text configured in the texts tool
-- at the spot the local player is looking at.
function SurfaceText:draw_text_preview()
  local client = PLAYER
  local tool = client:GetTool()
  local text = tool:GetClientInfo('text')
  local style = tool:GetClientNumber('style')
  local trace = client:GetEyeTrace()
  local normal = trace.HitNormal
  local font = Theme.get_font('text_3d2d')
  local w, h = util.text_size(text, font)
  local pos_x, pos_y = -w * 0.5, -h * 0.5
  local angle = normal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  start_3d2d(trace.HitPos + (normal * 1.25), angle, 0.1 * tool:GetClientNumber('scale'))
    if style >= 5 then
      local wide = w + 64
      local bar_x, bar_y = pos_x - 32, pos_y - 16

      if style != 8 and style != 9 then
        rounded_box(
          0,
          bar_x,
          bar_y,
          wide,
          h + 32,
          Color(tool:GetClientNumber('r2', 0), tool:GetClientNumber('g2', 0), tool:GetClientNumber('b2', 0), 40)
        )
      end

      if style == 7 or style == 8 then
        local bar_color = Color(255, 255, 255, 40)

        rounded_box(0, bar_x, bar_y, wide, 6, bar_color)
        rounded_box(0, bar_x, pos_y + h + 10, wide, 6, bar_color)
      elseif style == 9 then
        local bar_color = Color(255, 255, 255, 40)
        local rect_width = (wide / 3 - wide / 6) * 0.75
        local middle_width = wide / 1.75
        local middle_x = -middle_width * 0.5

        -- Draw left thick rectangles
        rounded_box(0, bar_x, bar_y - 6, rect_width, 10, bar_color)
        rounded_box(0, bar_x, bar_y + h + 22, rect_width, 10, bar_color)

        -- ...and the right ones
        rounded_box(0, bar_x + wide - rect_width, bar_y - 6, rect_width, 10, bar_color)
        rounded_box(0, bar_x + wide - rect_width, bar_y + h + 22, rect_width, 10, bar_color)

        -- And the middle thingies
        rounded_box(0, middle_x, bar_y, middle_width, 4, bar_color)
        rounded_box(0, middle_x, bar_y + h + 22, middle_width, 4, bar_color)
      end
    end

    simple_text(
      text,
      font,
      pos_x,
      pos_y,
      Color(tool:GetClientNumber('r', 0), tool:GetClientNumber('g', 0), tool:GetClientNumber('b', 0), 60)
    )
  end_3d2d()
end

--- Draws a preview of the picture configured in the pictures tool at the spot the local
-- player is looking at. A red box is drawn instead if the URL is not a png or jpg image.
function SurfaceText:draw_picture_preview()
  local client = PLAYER
  local tool = client:GetTool()
  local url = tool:GetClientInfo('url')
  local width = tool:GetClientNumber('width')
  local height = tool:GetClientNumber('height')
  local trace = client:GetEyeTrace()
  local normal = trace.HitNormal
  local angle = normal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  start_3d2d(trace.HitPos + (normal * 1.25), angle, 0.1)
    if url:end_with('.png') or url:end_with('.jpg') or url:end_with('.jpeg') then
      draw.textured_rect(URLMaterial(url), -width * 0.5, -height * 0.5, width, height, color_white)
    else
      rounded_box(0, -width * 0.5, -height * 0.5, width, height, Color(255, 0, 0, 40))
    end
  end_3d2d()
end
