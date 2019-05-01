library 'Font'

-- We want the fonts to recreate on refresh.
local stored = {}

do
  local aspect = ScrW() / ScrH()

  local function screen_is_ratio(w, h)
    return (aspect == w / h)
  end

  function Font.scale(size)
    if screen_is_ratio(16, 9) then
      return math.floor(size * (ScrH() / 1080))
    elseif screen_is_ratio(4, 3) then
      return math.floor(size * (ScrH() / 1024))
    end

    return math.floor(size * (ScrH() / 1200))
  end
end

function Font.create(name, font_data)
  if name == nil or !istable(font_data) then return end
  if stored[name] then return end

  -- Force UTF-8 range by default.
  font_data.extended = true

  surface.CreateFont(name, font_data)
  stored[name] = font_data

  return stored[name]
end

function Font.size(name, size, data)
  if !size then return name end
  if !name then return false end

  local font = stored[name]

  if font and font.size == size then
    return name
  end

  local new_name = name

  if string.match(new_name, ':(%d)') != size then
    new_name = new_name..':'..size
  end

  if !stored[new_name] then
    local font_data = table.Copy(stored[name])

    if font_data then
      if !istable(data) then data = {} end

      font_data.size = size

      table.merge(font_data, data)

      Font.create(new_name, font_data)
    end
  end

  return new_name
end

function Font.clear()
  stored = {}
end

function Font.get(name)
  return stored[name]
end

function Font.create_fonts()
  Font.clear()

  Font.create('flRoboto', {
    font = 'Roboto',
    size = 16,
    weight = 500
  })

  Font.create('flRobotoLight', {
    font = 'Roboto Lt',
    size = 16,
    weight = 200
  })

  Font.create('flRobotoBold', {
    font = 'Roboto',
    size = 16,
    weight = 1000,
  })

  Font.create('flRobotoItalic', {
    font = 'Roboto',
    size = 16,
    italic = true
  })

  Font.create('flRobotoItalicBold', {
    font = 'Roboto',
    size = 16,
    italic = true,
    weight = 1000
  })

  Font.create('flRobotoLt', {
    font = 'Roboto Lt',
    size = 16,
    weight = 500
  })

  Font.create('flRobotoLtBold', {
    font = 'Roboto Lt',
    size = 16,
    weight = 1000,
  })

  Font.create('flRobotoLtItalic', {
    font = 'Roboto Lt',
    size = 16,
    italic = true
  })

  Font.create('flRobotoLtItalicBold', {
    font = 'Roboto Lt',
    size = 16,
    italic = true,
    weight = 1000
  })

  Font.create('flRobotoCondensed', {
    font = 'Roboto Condensed',
    size = 16,
    weight = 500
  })

  Font.create('flRobotoCondensedBold', {
    font = 'Roboto Condensed',
    size = 16,
    weight = 1000,
  })

  Font.create('flRobotoCondensedItalic', {
    font = 'Roboto Condensed',
    size = 16,
    italic = true
  })

  Font.create('flRobotoCondensedItalicBold', {
    font = 'Roboto Condensed',
    size = 16,
    italic = true,
    weight = 1000
  })

  Theme.call('CreateFonts')
  hook.run('CreateFonts')
end
