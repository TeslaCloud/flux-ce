DeriveGamemode("sandbox")

do
  local centerX, centerY = ScrW() * 0.5, ScrH() * 0.5

  function ScrC()
    return centerX, centerY
  end
end

do
  local default_color_mod = {
    ["$pp_colour_addr"] = 0,
    ["$pp_colour_addg"] = 0,
    ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"] = 1,
    ["$pp_colour_colour"] = 1,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0
  }

  function fl.color_mod_enabled(enable)
    if !fl.client.color_mod_table then
      fl.client.color_mod_table = default_color_mod
    end

    if enable then
      fl.client.color_mod = true

      return true
    end

    fl.client.color_mod = false
  end

  function enable_color_mod()
    return fl.color_mod_enabled(true)
  end

  function fl.disable_color_mod()
    return fl.color_mod_enabled(false)
  end

  function fl.set_color_mod(index, value)
    if !fl.client.color_mod_table then
      fl.client.color_mod_table = default_color_mod
    end

    if isstring(index) then
      if !index:starts("$pp_colour_") then
        if index == "color" then index = "colour" end

        fl.client.color_mod_table["$pp_colour_"..index] = (isnumber(value) and value) or 0
      else
        fl.client.color_mod_table[index] = (isnumber(value) and value) or 0
      end
    end
  end

  function fl.set_color_mod_table(tab)
    if istable(tab) then
      fl.client.color_mod_table = tab
    end
  end
end

function fl.set_circle_percent(percentage)
  fl.client.circleActionPercentage = tonumber(percentage) or -1
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
      Try("draw_scaled", callback, pos_x, pos_y, scale)
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
      Try("draw_rotated", callback, pos_x, pos_y, angle)
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
      error("surface.draw_circle - Too few arguments to function call (3 expected)")
    end

    -- In case no passes variable was passed, in which case we give a normal smooth circle.
    passes = passes or 100

    local id = x.."|"..y.."|"..radius.."|"..passes
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


  local function scale_vertices(vertices, scale_x, scale_y)
    for k, v in pairs(vertices) do
      v.x = v.x * scale_x
      v.y = v.y * scale_y
    end
  end

  function surface.draw_circle_partial(percentage, x, y, radius, passes)
    if !percentage or !x or !y or !radius then
      error("surface.draw_circle_partial - Too few arguments to function call (4 expected)")
    end

    -- In case no passes variable was passed, in which case we give a normal smooth circle.
    passes = passes or 360

    local id = percentage.."|"..x.."|"..y.."|"..radius.."|"..passes
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

  function surface.draw_circle_outlined(x, y, radius, thickness, passes)
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

  function surface.draw_circle_outlined_partial(percentage, x, y, radius, thickness, passes)
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

do
  local ang = 0

  function fl.draw_rotating_cog(x, y, w, h, color)
    color = color or Color(255, 255, 255)

    surface.draw_rotated(x, y, ang, function(x, y, ang)
      draw.textured_rect(util.get_material("materials/flux/cog.png"), x - w * 0.5, y - h * 0.5, w, h, color)
    end)

    ang = ang + FrameTime() * 32

    if ang >= 360 then
      ang = 0
    end
  end
end
