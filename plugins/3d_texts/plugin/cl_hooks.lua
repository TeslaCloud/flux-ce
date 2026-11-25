--- Client side of the 3D Texts plugin: draws the placed texts and pictures in the world, and
-- the placement preview of the Text Tool and the Picture Placer. What a text or picture needs
-- for drawing and does not change is worked out once and kept in its `draw_cache` field.

local blur_texture = Material('pp/blurscreen')
local Color = Color
local clamp = math.Clamp
local sqrt = math.sqrt
local abs = math.abs
local sin = math.sin
local start_3d2d = cam.Start3D2D
local end_3d2d = cam.End3D2D
local rounded_box = draw.RoundedBox
local simple_text = draw.SimpleText
local fade_scale = 255 / 256
local box_color = Color(0, 0, 0)
local bar_color = Color(255, 255, 255)
local shadow_color = Color(0, 0, 0)
local dark_text_color = Color(0, 0, 0)
local text_draw_color = Color(255, 255, 255)
local picture_color = Color(255, 255, 255)
local preview_bar_color = Color(255, 255, 255, 40)
local preview_invalid_color = Color(255, 0, 0, 40)
local placeholder_name = Material('vgui/wave'):GetName()

--- Copies a color into one of the colors that are kept for drawing, at an opacity, so that
-- drawing does not create colors every frame.
-- @param target [Color color to write to]
-- @param source [Color color to copy]
-- @param alpha [Number opacity from 0 to 255]
-- @return [Color the target]
local function tint(target, source, alpha)
  target.r, target.g, target.b, target.a = source.r, source.g, source.b, alpha

  return target
end

--- Draws the bars of the boxed text styles 7, 8 and 9 around a text box.
-- @param style [Number text style]
-- @param x [Number left edge of the box]
-- @param y [Number top edge of the box]
-- @param w [Number width of the box]
-- @param h [Number height of the text]
-- @param color [Color color of the bars]
local function draw_text_bars(style, x, y, w, h, color)
  if style == 7 or style == 8 then
    rounded_box(0, x, y, w, 6, color)
    rounded_box(0, x, y + h + 26, w, 6, color)
  elseif style == 9 then
    local rect_width = (w / 3 - w / 6) * 0.75
    local middle_width = w / 1.75
    local middle_x = -middle_width * 0.5

    rounded_box(0, x, y - 6, rect_width, 10, color)
    rounded_box(0, x, y + h + 22, rect_width, 10, color)

    rounded_box(0, x + w - rect_width, y - 6, rect_width, 10, color)
    rounded_box(0, x + w - rect_width, y + h + 22, rect_width, 10, color)

    rounded_box(0, middle_x, y, middle_width, 4, color)
    rounded_box(0, middle_x, y + h + 22, middle_width, 4, color)
  end
end

--- Works out the draw positions, the scale and the darkened color of a text.
-- @param v [Map the text]
-- @return [Map the draw cache of the text]
local function cache_text(v)
  local pos, normal, scale = v.pos, v.normal, v.scale
  local color = v.color
  local cache = {
    base_pos = pos + normal * 0.4,
    shadow_pos = pos + normal * (0.95 * (scale + 0.5)),
    front_pos = pos + normal * (1.25 * (scale + 0.5)),
    text_scale = 0.1 * scale,
    dark_color = Color(color.r, color.g, color.b):darken(30)
  }

  v.draw_cache = cache

  return cache
end

--- Works out the draw position of a picture, and keeps its material once it has loaded.
-- @param v [Map the picture]
-- @return [Map the draw cache of the picture]
local function cache_picture(v)
  local cache = v.draw_cache

  if !cache then
    cache = { base_pos = v.pos + v.normal * 0.4 }
    v.draw_cache = cache
  end

  local material = URLMaterial(v.url)

  if material:GetName() != placeholder_name then
    cache.material = material
  end

  return cache, material
end

--- Draws the blurred box of text style 10 through the stencil, and puts the blur amount of the
-- shared screen blur material back afterwards.
-- @param x [Number left edge of the box]
-- @param y [Number top edge of the box]
-- @param w [Number width of the box]
-- @param h [Number height of the box]
-- @param back_color [Color secondary color of the text]
local function draw_blur_box(x, y, w, h, back_color)
  render.ClearStencil()
  render.SetStencilEnable(true)
  render.SetStencilCompareFunction(STENCIL_ALWAYS)
  render.SetStencilPassOperation(STENCIL_REPLACE)
  render.SetStencilFailOperation(STENCIL_KEEP)
  render.SetStencilZFailOperation(STENCIL_KEEP)
  render.SetStencilWriteMask(254)
  render.SetStencilTestMask(254)
  render.SetStencilReferenceValue(75)

  surface.SetDrawColor(255, 255, 255, 10)
  surface.DrawRect(x, y, w, h)

  render.SetStencilCompareFunction(STENCIL_EQUAL)

  render.SetMaterial(blur_texture)

  local previous = blur_texture:GetFloat('$blur')

  for j = 0, 1, 0.3 do
    blur_texture:SetFloat('$blur', j * 8)
    blur_texture:Recompute()
    render.UpdateScreenEffectTexture()
    render.DrawScreenQuad()
  end

  if previous then
    blur_texture:SetFloat('$blur', previous)
    blur_texture:Recompute()
  end

  render.SetStencilEnable(false)

  surface.SetDrawColor(back_color.r, back_color.g, back_color.b, 10)
  surface.DrawRect(x, y, w, h)
end

--- Draws every placed 3D text and picture within fade range of the local player,
-- plus a placement preview while the texts or pictures tool is equipped.
-- @param depth [Boolean whether the depth pass is being drawn]
-- @param skybox [Boolean whether the skybox is being drawn]
function SurfaceText:PostDrawOpaqueRenderables(depth, skybox)
  local client = PLAYER

  if depth or skybox or !IsValid(client) then return end

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
    local fade_offset = v.fade_offset or 0
    local draw_distance = 1024 + fade_offset

    if draw_distance < 0 or dist_sqr > draw_distance * draw_distance then continue end

    local distance = sqrt(dist_sqr)
    local fade_alpha = 255

    if distance > 768 + fade_offset then
      fade_alpha = clamp((draw_distance - distance) * fade_scale, 0, 255)
    end

    local cache = v.draw_cache or cache_text(v)
    local angle = v.angle
    local text = v.text
    local text_color = v.color
    local back_color = v.extra_color
    local style = v.style
    local text_scale = cache.text_scale
    local w, h = util.text_size(text, font)
    local pos_x, pos_y = -w * 0.5, -h * 0.5

    if style >= 2 then
      start_3d2d(cache.base_pos, angle, text_scale)
        if style >= 5 then
          local box_alpha = back_color.a
          local box_x, box_y = pos_x - 32, pos_y - 16
          local box_w = w + 64

          if style == 6 then
            box_alpha *= abs(sin(CurTime() * 3))
          end

          if style == 10 then
            draw_blur_box(box_x, box_y, box_w, h + 32, back_color)
          elseif style != 8 and style != 9 then
            rounded_box(0, box_x, box_y, box_w, h + 32, tint(box_color, back_color, clamp(fade_alpha, 0, box_alpha)))
          end

          bar_color.a = clamp(fade_alpha, 0, box_alpha)

          draw_text_bars(style, box_x, box_y, box_w, h, bar_color)
        end

        if style != 3 then
          simple_text(text, font, pos_x, pos_y, tint(dark_text_color, cache.dark_color, clamp(fade_alpha, 0, 100)))
        end
      end_3d2d()
    end

    if style >= 3 then
      shadow_color.a = clamp(fade_alpha, 0, 240)

      start_3d2d(cache.shadow_pos, angle, text_scale)
        simple_text(text, font, pos_x, pos_y, shadow_color)
      end_3d2d()
    end

    start_3d2d(cache.front_pos, angle, text_scale)
      simple_text(text, font, pos_x, pos_y, tint(text_draw_color, text_color, fade_alpha))
    end_3d2d()
  end

  local pictures = self.pictures

  for i = 1, #pictures do
    local v = pictures[i]
    local pos = v.pos
    local dist_sqr = client_pos:DistToSqr(pos)
    local fade_offset = v.fade_offset or 0
    local draw_distance = 1024 + fade_offset

    if draw_distance < 0 or dist_sqr > draw_distance * draw_distance then continue end

    local distance = sqrt(dist_sqr)
    local fade_alpha = 255

    if distance > 768 + fade_offset then
      fade_alpha = clamp((draw_distance - distance) * fade_scale, 0, 255)
    end

    local cache = v.draw_cache
    local material = cache and cache.material

    if !material then
      cache, material = cache_picture(v)
    end

    local height = v.height
    local width = v.width

    picture_color.a = fade_alpha

    start_3d2d(cache.base_pos, v.angle, 0.1)
      draw.textured_rect(material, -width * 0.5, -height * 0.5, width, height, picture_color)
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

  start_3d2d(trace.HitPos + (normal * 1.25), self:surface_angle(normal), 0.1 * tool:GetClientNumber('scale'))
    if style >= 5 then
      local wide = w + 64
      local bar_x, bar_y = pos_x - 32, pos_y - 16

      if style != 8 and style != 9 then
        box_color.r = tool:GetClientNumber('r2', 0)
        box_color.g = tool:GetClientNumber('g2', 0)
        box_color.b = tool:GetClientNumber('b2', 0)
        box_color.a = 40

        rounded_box(0, bar_x, bar_y, wide, h + 32, box_color)
      end

      draw_text_bars(style, bar_x, bar_y, wide, h, preview_bar_color)
    end

    text_draw_color.r = tool:GetClientNumber('r', 0)
    text_draw_color.g = tool:GetClientNumber('g', 0)
    text_draw_color.b = tool:GetClientNumber('b', 0)
    text_draw_color.a = 60

    simple_text(text, font, pos_x, pos_y, text_draw_color)
  end_3d2d()
end

--- Draws a preview of the picture configured in the pictures tool at the spot the local
-- player is looking at. A red box is drawn instead if the URL cannot be placed.
-- @see [SurfaceText:is_picture_url]
function SurfaceText:draw_picture_preview()
  local client = PLAYER
  local tool = client:GetTool()
  local url = tool:GetClientInfo('url')
  local width = tool:GetClientNumber('width')
  local height = tool:GetClientNumber('height')
  local trace = client:GetEyeTrace()
  local normal = trace.HitNormal

  start_3d2d(trace.HitPos + (normal * 1.25), self:surface_angle(normal), 0.1)
    if self:is_picture_url(url) then
      picture_color.a = 255

      draw.textured_rect(URLMaterial(url), -width * 0.5, -height * 0.5, width, height, picture_color)
    else
      rounded_box(0, -width * 0.5, -height * 0.5, width, height, preview_invalid_color)
    end
  end_3d2d()
end
