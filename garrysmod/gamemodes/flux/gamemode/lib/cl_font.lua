library.new 'font'

-- We want the fonts to recreate on refresh.
local stored = {}

do
  local aspect = ScrW() / ScrH()

  local function screen_is_ratio(w, h)
    return (aspect == w / h)
  end

  function font.scale(size)
    if screen_is_ratio(16, 9) then
      return math.floor(size * (ScrH() / 1080))
    elseif screen_is_ratio(4, 3) then
      return math.floor(size * (ScrH() / 1024))
    end

    return math.floor(size * (ScrH() / 1200))
  end
end

function font.create(name, font_data)
  if name == nil or !istable(font_data) then return end
  if stored[name] then return end

  -- Force UTF-8 range by default.
  font_data.extended = true

  surface.CreateFont(name, font_data)
  stored[name] = font_data
end

function font.size(name, size, data)
  if !size then return name end

  local new_name = name..':'..size

  if !stored[new_name] then
    local font_data = table.Copy(stored[name])

    if font_data then
      if !istable(data) then data = {} end

      font_data.size = size

      table.merge(font_data, data)

      font.create(new_name, font_data)
    end
  end

  return new_name
end

function font.clear()
  stored = {}
end

function font.clear_sizes()
  for k, v in pairs(stored) do
    if k:find('\\') then
      stored[k] = nil
    end
  end
end

function font.get(name)
  return stored[name]
end

function font.create_fonts()
  font.clear()

  font.create('flRoboto', {
    font = 'Roboto',
    size = 16,
    weight = 500
  })

  font.create('flRobotoLight', {
    font = 'Roboto Lt',
    size = 16,
    weight = 200
  })

  font.create('flRobotoBold', {
    font = 'Roboto',
    size = 16,
    weight = 1000,
  })

  font.create('flRobotoItalic', {
    font = 'Roboto',
    size = 16,
    italic = true
  })

  font.create('flRobotoItalicBold', {
    font = 'Roboto',
    size = 16,
    italic = true,
    weight = 1000
  })

  font.create('flRobotoLt', {
    font = 'Roboto Lt',
    size = 16,
    weight = 500
  })

  font.create('flRobotoLtBold', {
    font = 'Roboto Lt',
    size = 16,
    weight = 1000,
  })

  font.create('flRobotoLtItalic', {
    font = 'Roboto Lt',
    size = 16,
    italic = true
  })

  font.create('flRobotoLtItalicBold', {
    font = 'Roboto Lt',
    size = 16,
    italic = true,
    weight = 1000
  })

  font.create('flRobotoCondensed', {
    font = 'Roboto Condensed',
    size = 16,
    weight = 500
  })

  font.create('flRobotoCondensedBold', {
    font = 'Roboto Condensed',
    size = 16,
    weight = 1000,
  })

  font.create('flRobotoCondensedItalic', {
    font = 'Roboto Condensed',
    size = 16,
    italic = true
  })

  font.create('flRobotoCondensedItalicBold', {
    font = 'Roboto Condensed',
    size = 16,
    italic = true,
    weight = 1000
  })

  theme.call('CreateFonts')
  hook.run('CreateFonts')
end

_font = font
