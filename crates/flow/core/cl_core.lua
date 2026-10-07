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

  --- Returns the coordinates of the center of the screen. The values are computed once when
  -- the file loads.
  -- @return [Number x, Number y]
  function ScrC()
    return center_x, center_y
  end
end

--- Sets the fill percentage of the circular action indicator drawn in the middle of the HUD.
-- The value is cleared after every draw, so call this each frame while it should be visible.
-- @param percentage [Number fill percentage from 0 to 100]
-- @param alpha=255 [Number opacity of the indicator from 0 to 255]
function Flux.set_circle_percent(percentage, alpha)
  PLAYER.circle_action_percentage = math.clamp(tonumber(percentage), 0, 100)
  PLAYER.circle_action_alpha = math.clamp(tonumber(alpha or 255), 0, 255)
end

--- Draws text scaled around its top left corner.
-- @param text [String]
-- @param font_name [String]
-- @param pos_x [Number screen x of the text]
-- @param pos_y [Number screen y of the text]
-- @param scale [Number scale factor, 1 for the normal size]
-- @param color [Color]
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

--- Draws text rotated around its top left corner.
-- @param text [String]
-- @param font_name [String]
-- @param pos_x [Number screen x of the text]
-- @param pos_y [Number screen y of the text]
-- @param angle [Number rotation in degrees]
-- @param color [Color]
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

--- Runs a drawing callback with everything it draws scaled around the given point.
-- Errors raised inside the callback are caught and reported.
-- @param pos_x [Number screen x of the scaling origin]
-- @param pos_y [Number screen y of the scaling origin]
-- @param scale [Number scale factor, 1 for the normal size]
-- @param callback [Function draws the contents; called with (pos_x, pos_y, scale)]
function surface.draw_scaled(pos_x, pos_y, scale, callback)
  local matrix = Matrix()
  local pos = Vector(pos_x, pos_y)

  matrix:Translate(pos)
  matrix:Scale(Vector(1, 1, 0) * scale)
  matrix:Rotate(Angle(0, 0, 0))
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    if callback then
      try(callback, pos_x, pos_y, scale)
    end
  cam.PopModelMatrix()
end

--- Runs a drawing callback with everything it draws rotated around the given point.
-- Errors raised inside the callback are caught and reported.
-- @param pos_x [Number screen x of the rotation origin]
-- @param pos_y [Number screen y of the rotation origin]
-- @param angle [Number rotation in degrees]
-- @param callback [Function draws the contents; called with (pos_x, pos_y, angle)]
function surface.draw_rotated(pos_x, pos_y, angle, callback)
  local matrix = Matrix()
  local pos = Vector(pos_x, pos_y)

  matrix:Translate(pos)
  matrix:Rotate(Angle(0, angle, 0))
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    if callback then
      try(callback, pos_x, pos_y, angle)
    end
  cam.PopModelMatrix()
end

--- Checks whether the mouse cursor is inside a rectangle given in screen coordinates.
-- @param x [Number]
-- @param y [Number]
-- @param w [Number width]
-- @param h [Number height]
-- @return [Boolean]
function surface.mouse_in_rect(x, y, w, h)
  local mx, my = gui.MousePos()
  return (mx >= x and mx <= x + w and my >= y and my <= y + h)
end

do
  local cache = {}

  --- Draws a filled circle in the current surface draw color. Raises an error if x, y or
  -- radius is missing. The vertices are cached for every distinct set of arguments.
  -- @param x [Number screen x of the center]
  -- @param y [Number screen y of the center]
  -- @param radius [Number]
  -- @param passes=100 [Number amount of segments; more of them make a smoother circle]
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

  --- Draws a filled sector of a circle in the current surface draw color, starting at the top
  -- and going clockwise. Raises an error if percentage, x, y or radius is missing.
  -- @param percentage [Number how much of the circle to draw, from 0 to 100]
  -- @param x [Number screen x of the center]
  -- @param y [Number screen y of the center]
  -- @param radius [Number]
  -- @param passes=360 [Number amount of segments a full circle would have]
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
        table.insert(info, { x = 0, y = 0 })
      end

      for i = start_angle, end_angle + step, step do
        i = math.Clamp(i, start_angle, end_angle)

        local rads = math.rad(i)
        local x = math.cos(rads)
        local y = math.sin(rads)

        table.insert(info, { x = x, y = y })
      end

      for k, v in ipairs(info) do
        v.x = v.x * radius + x
        v.y = v.y * radius + y
      end

      cache[id] = info
    end

    surface.DrawPoly(info)
  end

  --- Draws a ring in the current surface draw color. Uses the stencil buffer.
  -- @param x [Number screen x of the center]
  -- @param y [Number screen y of the center]
  -- @param radius [Number outer radius]
  -- @param thickness=1 [Number width of the ring in pixels]
  -- @param passes=100 [Number amount of segments; more of them make a smoother circle]
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

  --- Draws a part of a ring in the current surface draw color, starting at the top and going
  -- clockwise. Uses the stencil buffer.
  -- @param percentage [Number how much of the ring to draw, from 0 to 100]
  -- @param x [Number screen x of the center]
  -- @param y [Number screen y of the center]
  -- @param radius [Number outer radius]
  -- @param thickness=1 [Number width of the ring in pixels]
  -- @param passes=360 [Number amount of segments a full circle would have]
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

--- Draws with a cutout: whatever draw_func draws is only visible outside of the area that
-- stencil_func draws. Does nothing unless both arguments are functions.
-- ```
-- -- A 2 pixel wide frame: the outer box minus the inner box.
-- draw.stenciled(function()
--   draw.RoundedBox(0, x, y, w, h, color)
-- end, function()
--   draw.RoundedBox(0, x + 2, y + 2, w - 4, h - 4, color)
-- end)
-- ```
-- @param draw_func [Function draws the visible contents; called without arguments]
-- @param stencil_func [Function draws the area to cut out; its output is not shown]
function draw.stenciled(draw_func, stencil_func)
  if !isfunction(draw_func) or !isfunction(stencil_func) then return end

  render.ClearStencil()
  render.SetStencilEnable(true)
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)
    render.SetStencilReferenceValue(29)
    render.SetStencilFailOperation(STENCIL_REPLACE)

    render.SetStencilCompareFunction(STENCIL_EQUAL)
      stencil_func()
    render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
      draw_func()
  render.SetStencilEnable(false)
  render.ClearStencil()
end

--- Draws the outline of a rounded box, leaving its inside untouched.
-- @param rounding [Number corner radius of the outer edge]
-- @param x [Number]
-- @param y [Number]
-- @param w [Number width]
-- @param h [Number height]
-- @param thickness [Number width of the outline in pixels]
-- @param color [Color]
-- @param rounding2=rounding [Number corner radius of the inner edge]
-- @see [draw.stenciled]
function draw.box_outlined(rounding, x, y, w, h, thickness, color, rounding2)
  rounding2 = rounding2 or rounding

  draw.stenciled(function()
    draw.RoundedBox(rounding, x, y, w, h, color)
  end, function()
    draw.RoundedBox(rounding2, x + thickness, y + thickness, w - thickness * 2, h - thickness * 2, color)
  end)
end

--- Draws a rectangle textured with a material. Does nothing if no material is given.
-- @param material [Material]
-- @param x [Number]
-- @param y [Number]
-- @param w [Number width]
-- @param h [Number height]
-- @param color=Color(255, 255, 255) [Color tint of the material]
function draw.textured_rect(material, x, y, w, h, color)
  if !material then return end

  color = (IsColor(color) and color) or Color(255, 255, 255)

  surface.SetDrawColor(color.r, color.g, color.b, color.a)
  surface.SetMaterial(material)
  surface.DrawTexturedRect(x, y, w, h)
end

--- Draws a solid rectangle.
-- @param x [Number]
-- @param y [Number]
-- @param w [Number width]
-- @param h [Number height]
-- @param color=Color(255, 255, 255) [Color]
function draw.box(x, y, w, h, color)
  surface.SetDrawColor(color or Color(255, 255, 255))
  surface.DrawRect(x, y, w, h)
end

--- Sets the strength of the blur used by draw.blur_box and draw.blur_panel.
-- @param size=12 [Number]
-- @return [Number the size that was set]
function draw.set_blur_size(size)
  size = size or 12
  Flux.blur_size = size
  return size
end

--- Draws a blurred copy of the screen inside a rectangle given in screen coordinates.
-- To be called outside of a panel. Also requests the blur texture to be kept up to date.
-- @param x [Number]
-- @param y [Number]
-- @param w [Number width]
-- @param h [Number height]
function draw.blur_box(x, y, w, h)
  render.SetScissorRect(x, y, x + w, y + h, true)
    render.SetMaterial((Flux.should_render_blur != nil) and Flux.blur_mat or Flux.blur_material)
    render.DrawScreenQuad()
  render.SetScissorRect(0, 0, 0, 0, false)

  Flux.should_render_blur = true
end

--- Draws a blurred copy of the screen behind a panel, using the position reported by
-- panel:GetPos() and the size of the panel. Also requests the blur texture to be kept
-- up to date.
-- @param panel [Panel]
function draw.blur_panel(panel)
  local x, y = panel:GetPos()
  local w, h = panel:GetSize()

  render.SetScissorRect(x, y, x + w, y + h, true)
    render.SetMaterial((Flux.should_render_blur != nil) and Flux.blur_mat or Flux.blur_material)
    render.DrawScreenQuad()
  render.SetScissorRect(0, 0, 0, 0, false)

  Flux.should_render_blur = true
end

--- Draws a line between two points.
-- @param x [Number x of the first point]
-- @param y [Number y of the first point]
-- @param x2 [Number x of the second point]
-- @param y2 [Number y of the second point]
-- @param color [Color]
function draw.line(x, y, x2, y2, color)
  surface.SetDrawColor(color)
  surface.DrawLine(x, y, x2, y2)
end

do
  local ang = 0

  --- Draws a spinning cog icon, usually as a loading indicator. All cogs drawn in a frame
  -- share one rotation, which advances with every call.
  -- @param x [Number screen x of the center of the cog]
  -- @param y [Number screen y of the center of the cog]
  -- @param w [Number width]
  -- @param h [Number height]
  -- @param color=Color(255, 255, 255) [Color]
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

  --- Creates or overwrites the state of a position animation.
  -- @param id [String unique ID of the animation]
  -- @param x [Number current x, or nil to leave the x axis unanimated]
  -- @param y [Number current y, or nil to leave the y axis unanimated]
  -- @param delta [Number fraction of the remaining distance covered on every draw, 0 to 1]
  -- @return [Hash the animation state with the x, y and delta fields]
  -- @see [Flux.draw_animation]
  function Flux.update_animation(id, x, y, delta)
    anim_cache[id] = { x = x, y = y, delta = delta }
    return anim_cache[id]
  end

  --- Creates the state of a position animation unless one with this ID already exists, which
  -- makes it safe to call every frame.
  -- @param id [String unique ID of the animation]
  -- @param x [Number starting x, or nil to leave the x axis unanimated]
  -- @param y [Number starting y, or nil to leave the y axis unanimated]
  -- @param delta [Number fraction of the remaining distance covered on every draw, 0 to 1]
  -- @see [Flux.draw_animation]
  function Flux.register_animation(id, x, y, delta)
    anim_cache[id] = anim_cache[id] or Flux.update_animation(id, x, y, delta)
  end

  --- Draws one frame of a registered position animation: calls the callback with the current
  -- position, then eases the position towards the target. Raises an error if the animation
  -- has not been registered.
  -- ```
  -- Flux.register_animation(anim_id, box_x - max_width, nil, FrameTime() * 8)
  --
  -- Flux.draw_animation(anim_id, box_x, box_y, function(x, y)
  --   draw.textured_rect(Theme.get_material('gradient'), x, y, box_width, box_height, accent_color)
  -- end)
  -- ```
  -- @param id [String ID of the animation]
  -- @param tx [Number target x]
  -- @param ty [Number target y]
  -- @param callback [Function draws the contents; called with the current (x, y), where an
  --   unanimated axis receives the target value]
  function Flux.draw_animation(id, tx, ty, callback)
    local anim = anim_cache[id]

    if !anim then error(id..' is not a registered animation!\n') end

    callback(anim.x or tx, anim.y or ty)

    if anim.x then anim.x = Lerp(anim.delta, anim.x, tx) end
    if anim.y then anim.y = Lerp(anim.delta, anim.y, ty) end
  end
end
