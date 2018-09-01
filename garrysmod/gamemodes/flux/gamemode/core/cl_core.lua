DeriveGamemode("sandbox")

if !fl.lang then
  include 'lib/sh_lang.lua'
end

do
  local centerX, centerY = ScrW() * 0.5, ScrH() * 0.5

  function ScrC()
    return centerX, centerY
  end
end

do
  local defaultColorModify = {
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

  function fl.SetColorModifyEnabled(bEnable)
    if (!fl.client.colorModifyTable) then
      fl.client.colorModifyTable = defaultColorModify
    end

    if (bEnable) then
      fl.client.colorModify = true

      return true
    end

    fl.client.colorModify = false
  end

  function fl.EnableColorModify()
    return fl.SetColorModifyEnabled(true)
  end

  function fl.DisableColorModify()
    return fl.SetColorModifyEnabled(false)
  end

  function fl.SetColorModifyVal(strIndex, nValue)
    if (!fl.client.colorModifyTable) then
      fl.client.colorModifyTable = defaultColorModify
    end

    if (isstring(strIndex)) then
      if (!strIndex:StartWith("$pp_colour_")) then
        if (strIndex == "color") then strIndex = "colour" end

        fl.client.colorModifyTable["$pp_colour_"..strIndex] = (isnumber(nValue) and nValue) or 0
      else
        fl.client.colorModifyTable[strIndex] = (isnumber(nValue) and nValue) or 0
      end
    end
  end

  function fl.SetColorModifyTable(tab)
    if (istable(tab)) then
      fl.client.colorModifyTable = tab
    end
  end
end

function fl.SetCirclePercentage(percentage)
  fl.client.circleActionPercentage = tonumber(percentage) or -1
end

function surface.DrawScaledText(strText, strFontName, nPosX, nPosY, nScale, color)
  local matrix = Matrix()
  local pos = Vector(nPosX, nPosY)

  matrix:Translate(pos)
  matrix:Scale(Vector(1, 1, 1) * nScale)
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    surface.SetFont(strFontName)
    surface.SetTextColor(color)
    surface.SetTextPos(nPosX, nPosY)
    surface.DrawText(strText)
  cam.PopModelMatrix()
end

function surface.DrawRotatedText(strText, strFontName, nPosX, nPosY, angle, color)
  local matrix = Matrix()
  local pos = Vector(nPosX, nPosY)

  matrix:Translate(pos)
  matrix:Rotate(Angle(0, angle, 0))
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    surface.SetFont(strFontName)
    surface.SetTextColor(color)
    surface.SetTextPos(nPosX, nPosY)
    surface.DrawText(strText)
  cam.PopModelMatrix()
end

function surface.DrawScaled(nPosX, nPosY, nScale, callback)
  local matrix = Matrix()
  local pos = Vector(nPosX, nPosY)

  matrix:Translate(pos)
  matrix:Scale(Vector(1, 1, 0) * nScale)
  matrix:Rotate(Angle(0, 0, 0))
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    if (callback) then
      Try("DrawScaled", callback, nPosX, nPosY, nScale)
    end
  cam.PopModelMatrix()
end

function surface.DrawRotated(nPosX, nPosY, angle, callback)
  local matrix = Matrix()
  local pos = Vector(nPosX, nPosY)

  matrix:Translate(pos)
  matrix:Rotate(Angle(0, angle, 0))
  matrix:Translate(-pos)

  cam.PushModelMatrix(matrix)
    if (callback) then
      Try("DrawRotated", callback, nPosX, nPosY, angle)
    end
  cam.PopModelMatrix()
end

function surface.IsMouseInRect(x, y, w, h)
  local mx, my = gui.MousePos()

  print(x, y, w, h, mx, my)

  return (mx >= x and mx <= x + w and my >= y and my <= y + h)
end

do
  local cache = {}

  function surface.DrawCircle(x, y, radius, passes)
    if (!x or !y or !radius) then
      error("surface.DrawCircle - Too few arguments to function call (3 expected)")
    end

    -- In case no passes variable was passed, in which case we give a normal smooth circle.
    passes = passes or 100

    local id = x.."|"..y.."|"..radius.."|"..passes
    local info = cache[id]

    if (!info) then
      info = {}

      for i = 1, passes + 1 do
        local degInRad = i * math.pi / (passes * 0.5)

        info[i] = {
          x = x + math.cos(degInRad) * radius,
          y = y + math.sin(degInRad) * radius
        }
      end

      cache[id] = info
    end

    draw.NoTexture() -- Otherwise we draw a transparent circle.
    surface.DrawPoly(info)
  end


  local function scaleVertices(tblVertices, iScaleX, iScaleY)
    for k, v in pairs(tblVertices) do
      v.x = v.x * iScaleX
      v.y = v.y * iScaleY
    end
  end

  function surface.DrawPartialCircle(percentage, x, y, radius, passes)
    if (!percentage or !x or !y or !radius) then
      error("surface.DrawPartialCircle - Too few arguments to function call (4 expected)")
    end

    -- In case no passes variable was passed, in which case we give a normal smooth circle.
    passes = passes or 360

    local id = percentage.."|"..x.."|"..y.."|"..radius.."|"..passes
    local info = cache[id]

    if (!info) then
      info = {}

      local startAngle, endAngle, step = -90, 360 / 100 * percentage - 90, 360 / passes

      if (math.abs(startAngle - endAngle) != 0) then
        table.insert(info, {x = 0, y = 0})
      end

      for i = startAngle, endAngle + step, step do
        i = math.Clamp(i, startAngle, endAngle)

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

  function surface.DrawOutlinedCircle(x, y, radius, thickness, passes)
    render.ClearStencil()
    render.SetStencilEnable(true)
      render.SetStencilWriteMask(255)
      render.SetStencilTestMask(255)
      render.SetStencilReferenceValue(28)
      render.SetStencilFailOperation(STENCIL_REPLACE)

      render.SetStencilCompareFunction(STENCIL_EQUAL)
        surface.DrawCircle(x, y, radius - (thickness or 1), passes)
      render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
        surface.DrawCircle(x, y, radius, passes)
    render.SetStencilEnable(false)
    render.ClearStencil()
  end

  function surface.DrawPartialOutlinedCircle(percentage, x, y, radius, thickness, passes)
    render.ClearStencil()
    render.SetStencilEnable(true)
      render.SetStencilWriteMask(255)
      render.SetStencilTestMask(255)
      render.SetStencilReferenceValue(28)
      render.SetStencilFailOperation(STENCIL_REPLACE)

      render.SetStencilCompareFunction(STENCIL_EQUAL)
        surface.DrawPartialCircle(percentage, x, y, radius - (thickness or 1), passes)
      render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
        surface.DrawPartialCircle(percentage, x, y, radius, passes)
    render.SetStencilEnable(false)
    render.ClearStencil()
  end
end

function draw.RoundedBoxOutline(rounding, x, y, w, h, thickness, color, rounding2)
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

function draw.TexturedRect(material, x, y, w, h, color)
  if (!material) then return end

  color = (IsColor(color) and color) or Color(255, 255, 255)

  surface.SetDrawColor(color.r, color.g, color.b, color.a)
  surface.SetMaterial(material)
  surface.DrawTexturedRect(x, y, w, h)
end

do
  local ang = 0

  function fl.DrawRotatingCog(x, y, w, h, color)
    color = color or Color(255, 255, 255)

    surface.DrawRotated(x, y, ang, function(x, y, ang)
      draw.TexturedRect(util.GetMaterial("materials/flux/cog.png"), x - w * 0.5, y - h * 0.5, w, h, color)
    end)

    ang = ang + FrameTime() * 32

    if (ang >= 360) then
      ang = 0
    end
  end
end
