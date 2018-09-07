library.new "font"

-- We want the fonts to recreate on refresh.
local stored = {}

do
  local aspect = ScrW() / ScrH()

  local function ScreenIsRatio(w, h)
    return (aspect == w / h)
  end

  function font.Scale(size)
    if ScreenIsRatio(16, 9) then
      return math.floor(size * (ScrH() / 1080))
    elseif ScreenIsRatio(4, 3) then
      return math.floor(size * (ScrH() / 1024))
    end

    return math.floor(size * (ScrH() / 1200))
  end
end

function font.Create(name, fontData)
  if name == nil or !istable(fontData) then return end
  if stored[name] then return end

  -- Force UTF-8 range by default.
  fontData.extended = true

  surface.CreateFont(name, fontData)
  stored[name] = fontData
end

function font.GetSize(name, size, data)
  if !size then return name end

  local newName = name..":"..size

  if !stored[newName] then
    local fontData = table.Copy(stored[name])

    if fontData then
      if !istable(data) then data = {} end

      fontData.size = size

      table.merge(fontData, data)

      font.Create(newName, fontData)
    end
  end

  return newName
end

function font.ClearTable()
  stored = {}
end

function font.ClearSizes()
  for k, v in pairs(stored) do
    if k:find("\\") then
      stored[k] = nil
    end
  end
end

function font.GetTable(name)
  return stored[name]
end

function font.CreateFonts()
  font.ClearTable()

  font.Create("flRoboto", {
    font = "Roboto",
    size = 16,
    weight = 500
  })

  font.Create("flRobotoBold", {
    font = "Roboto",
    size = 16,
    weight = 1000,
  })

  font.Create("flRobotoItalic", {
    font = "Roboto",
    size = 16,
    italic = true
  })

  font.Create("flRobotoItalicBold", {
    font = "Roboto",
    size = 16,
    italic = true,
    weight = 1000
  })

  font.Create("flRobotoLt", {
    font = "Roboto Lt",
    size = 16,
    weight = 500
  })

  font.Create("flRobotoLtBold", {
    font = "Roboto Lt",
    size = 16,
    weight = 1000,
  })

  font.Create("flRobotoLtItalic", {
    font = "Roboto Lt",
    size = 16,
    italic = true
  })

  font.Create("flRobotoLtItalicBold", {
    font = "Roboto Lt",
    size = 16,
    italic = true,
    weight = 1000
  })

  font.Create("flRobotoCondensed", {
    font = "Roboto Condensed",
    size = 16,
    weight = 500
  })

  font.Create("flRobotoCondensedBold", {
    font = "Roboto Condensed",
    size = 16,
    weight = 1000,
  })

  font.Create("flRobotoCondensedItalic", {
    font = "Roboto Condensed",
    size = 16,
    italic = true
  })

  font.Create("flRobotoCondensedItalicBold", {
    font = "Roboto Condensed",
    size = 16,
    italic = true,
    weight = 1000
  })

  theme.Call("CreateFonts")
  hook.run("CreateFonts")
end

_font = font
