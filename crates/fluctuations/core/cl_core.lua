DeriveGamemode('sandbox')

Flux.blur_material = Material('pp/blurscreen')
Flux.rt_texture = GetRenderTarget('fl_rt_'..os.time(), ScrW(), ScrH(), false)
Flux.blur_mat = CreateMaterial('fl_mat_'..os.time(), 'UnlitGeneric', {
  ['$basetexture'] = Flux.rt_texture
})
Flux.blur_size = 12
Flux.blur_passes = 8 -- anything below 8 looks chunky
Flux.blur_update_fps = 24 -- how many frames per second should we render the lazy blurs. 0 for unlimited.

do
  local center_x, center_y = ScrW() * 0.5, ScrH() * 0.5

  function ScrC()
    return center_x, center_y
  end
end

function Flux.set_circle_percent(percentage, alpha)
  PLAYER.circle_action_percentage = math.clamp(tonumber(percentage), 0, 100)
  PLAYER.circle_action_alpha = math.clamp(tonumber(alpha or 255), 0, 255)
end

function surface.draw_text_scaled(text, font_name, pos_x, pos_y, scale, color)
  local matrix = Matrix()
  local pos = Vector(pos_x, pos_y)

  matrix:Translate(pos)
  matrix:Scale(Vector(1, 1, 1) * scale)
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    surface.SetFont(font_name)
    surface.SetTextColor(color)
    surface.SetTextPos(pos_x, pos_y)
    surface.DrawText(text)
  cam.PopModelMatrix()
end

function surface.draw_text_rotated(text, font_name, pos_x, pos_y, angle, color)
  local matrix = Matrix()
  local pos = Vector(pos_x, pos_y)

  matrix:Translate(pos)
  matrix:Rotate(Angle(0, angle, 0))
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    surface.SetFont(font_name)
    surface.SetTextColor(color)
    surface.SetTextPos(pos_x, pos_y)
    surface.DrawText(text)
  cam.PopModelMatrix()
end

function surface.draw_scaled(pos_x, pos_y, scale, callback)
  local matrix = Matrix()
  local pos = Vector(pos_x, pos_y)

  matrix:Translate(pos)
  matrix:Scale(Vector(1, 1, 0) * scale)
  matrix:Rotate(Angle(0, 0, 0))
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    if callback then
      Try('draw_scaled', callback, pos_x, pos_y, scale)
    end
  cam.PopModelMatrix()
end

function surface.draw_rotated(pos_x, pos_y, angle, callback)
  local matrix = Matrix()
  local pos = Vector(pos_x, pos_y)

  matrix:Translate(pos)
  matrix:Rotate(Angle(0, angle, 0))
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    if callback then
      Try('draw_rotated', callback, pos_x, pos_y, angle)
    end
  cam.PopModelMatrix()
end

function surface.mouse_in_rect(x, y, w, h)
  local mx, my = gui.MousePos()
  return (mx >= x and mx <= x + w and my >= y and my <= y + h)
end

do
  local cache = {}

  function surface.draw_circle(x, y, radius, passes)
    if !x or !y or !radius then
      error('surface.draw_circle - Too few arguments to function call (3 expected)')
    end

    -- In case no passes variable was passed, in which case we give a normal smooth circle.
    passes = passes or 100

    local id = x..'|'..y..'|'..radius..'|'..passes
    local info = cache[id]

    if !info then
      info = {}

      for i = 1, passes + 1 do
        local deg_in_rad = i * math.pi / (passes * 0.5)

        info[i] = {
          x = x + math.cos(deg_in_rad) * radius,
          y = y + math.sin(deg_in_rad) * radius
        }
      end

      cache[id] = info
    end

    draw.NoTexture() -- Otherwise we draw a transparent circle.
    surface.DrawPoly(info)
  end

  function surface.draw_circle_partial(percentage, x, y, radius, passes)
    if !percentage or !x or !y or !radius then
      error('surface.draw_circle_partial - Too few arguments to function call (4 expected)')
    end

    -- In case no passes variable was passed, in which case we give a normal smooth circle.
    passes = passes or 360

    local id = percentage..'|'..x..'|'..y..'|'..radius..'|'..passes
    local info = cache[id]

    if !info then
      info = {}

      local start_angle, end_angle, step = -90, 360 / 100 * percentage - 90, 360 / passes

      if math.abs(start_angle - end_angle) != 0 then
        table.insert(info, {x = 0, y = 0})
      end

      for i = start_angle, end_angle + step, step do
        i = math.Clamp(i, start_angle, end_angle)

        local rads = math.rad(i)
        local x = math.cos(rads)
        local y = math.sin(rads)

        table.insert(info, {x = x, y = y})
      end

      for k, v in ipairs(info) do
        v.x = v.x * radius + x
        v.y = v.y * radius + y
      end

      cache[id] = info
    end

    surface.DrawPoly(info)
  end

  function surface.draw_circle_outline(x, y, radius, thickness, passes)
    render.ClearStencil()
    render.SetStencilEnable(true)
      render.SetStencilWriteMask(255)
      render.SetStencilTestMask(255)
      render.SetStencilReferenceValue(28)
      render.SetStencilFailOperation(STENCIL_REPLACE)

      render.SetStencilCompareFunction(STENCIL_EQUAL)
        surface.draw_circle(x, y, radius - (thickness or 1), passes)
      render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
        surface.draw_circle(x, y, radius, passes)
    render.SetStencilEnable(false)
    render.ClearStencil()
  end

  function surface.draw_circle_outline_partial(percentage, x, y, radius, thickness, passes)
    render.ClearStencil()
    render.SetStencilEnable(true)
      render.SetStencilWriteMask(255)
      render.SetStencilTestMask(255)
      render.SetStencilReferenceValue(28)
      render.SetStencilFailOperation(STENCIL_REPLACE)

      render.SetStencilCompareFunction(STENCIL_EQUAL)
        surface.draw_circle_partial(percentage, x, y, radius - (thickness or 1), passes)
      render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
        surface.draw_circle_partial(percentage, x, y, radius, passes)
    render.SetStencilEnable(false)
    render.ClearStencil()
  end
end

function draw.box_outlined(rounding, x, y, w, h, thickness, color, rounding2)
  rounding2 = rounding2 or rounding

  render.ClearStencil()
  render.SetStencilEnable(true)
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)
    render.SetStencilReferenceValue(29)
    render.SetStencilFailOperation(STENCIL_REPLACE)

    render.SetStencilCompareFunction(STENCIL_EQUAL)
      draw.RoundedBox(rounding2, x + thickness, y + thickness, w - thickness * 2, h - thickness * 2, color)
    render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
      draw.RoundedBox(rounding, x, y, w, h, color)
  render.SetStencilEnable(false)
  render.ClearStencil()
end

function draw.textured_rect(material, x, y, w, h, color)
  if !material then return end

  color = (IsColor(color) and color) or Color(255, 255, 255)

  surface.SetDrawColor(color.r, color.g, color.b, color.a)
  surface.SetMaterial(material)
  surface.DrawTexturedRect(x, y, w, h)
end

function draw.box(x, y, w, h, color)
  surface.SetDrawColor(color or Color(255, 255, 255))
  surface.DrawRect(x, y, w, h)
end

function draw.set_blur_size(size)
  size = size or 12
  Flux.blur_size = size
  return size
end

-- To be called outside of a panel
function draw.blur_box(x, y, w, h)
  render.SetScissorRect(x, y, x + w, y + h, true)
    render.SetMaterial((Flux.should_render_blur != nil) and Flux.blur_mat or Flux.blur_material)
    render.DrawScreenQuad()
  render.SetScissorRect(0, 0, 0, 0, false)

  Flux.should_render_blur = true
end

function draw.blur_panel(panel)
  local x, y = panel:GetPos()
  local w, h = panel:GetSize()

  render.SetScissorRect(x, y, x + w, y + h, true)
    render.SetMaterial((Flux.should_render_blur != nil) and Flux.blur_mat or Flux.blur_material)
    render.DrawScreenQuad()
  render.SetScissorRect(0, 0, 0, 0, false)

  Flux.should_render_blur = true
end

function draw.line(x, y, x2, y2, color)
  surface.SetDrawColor(color)
  surface.DrawLine(x, y, x2, y2)
end

do
  local ang = 0

  function Flux.draw_rotating_cog(x, y, w, h, color)
    color = color or Color(255, 255, 255)

    surface.draw_rotated(x, y, ang, function(x, y, ang)
      draw.textured_rect(util.get_material('materials/flux/cog.png'), x - w * 0.5, y - h * 0.5, w, h, color)
    end)

    ang = ang + FrameTime() * 32

    if ang >= 360 then
      ang = 0
    end
  end
end

do
  local anim_cache = {}

  function Flux.update_animation(id, x, y, delta)
    anim_cache[id] = { x = x, y = y, delta = delta }
    return anim_cache[id]
  end

  function Flux.register_animation(id, x, y, delta)
    anim_cache[id] = anim_cache[id] or Flux.update_animation(id, x, y, delta)
  end

  function Flux.draw_animation(id, tx, ty, callback)
    local anim = anim_cache[id]

    if !anim then error(id..' is not a registered animation!\n') end

    callback(anim.x or tx, anim.y or ty)

    if anim.x then anim.x = Lerp(anim.delta, anim.x, tx) end
    if anim.y then anim.y = Lerp(anim.delta, anim.y, ty) end
  end
end
