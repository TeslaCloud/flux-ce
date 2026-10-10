--- Creates and keeps track of the fonts of the Flux interface. `Font.create` wraps
-- `surface.CreateFont` and remembers the data of the font, which lets `Font.size` derive a
-- copy of any created font at another size on demand (named 'name:size'), so that the
-- interface can ask for a scaled font wherever it draws text. All fonts are created again by
-- `Font.create_fonts` when the gamemode loads on the client, once the schema has loaded and
-- whenever the screen resolution changes. It creates the built-in Roboto family ('flRoboto',
-- 'flRobotoCondensed' and so on) and then runs the `CreateFonts` theme hook and the
-- `CreateFonts` hook. Plugins create their fonts from a `CreateFonts` handler so that they
-- survive these rebuilds, and themes give fonts a role with `ThemeBase:set_font`, which the
-- interface looks up with `Theme.get_font`.

mod 'Font'

-- We want the fonts to recreate on refresh.
local stored = {}
local sized_names = {}

--- Creates a font and remembers its data. Does nothing if a font with this name
-- has already been created. The extended (UTF-8) character range is always enabled.
-- ```
-- Font.create('flRoboto', {
--   font = 'Roboto',
--   size = 16,
--   weight = 500
-- })
-- ```
-- @param name [String unique name of the new font]
-- @param font_data [Map font structure, same as the one surface.CreateFont accepts]
-- @return [Map the stored font data, or nil if the arguments are invalid or the font exists]
function Font.create(name, font_data)
  if name == nil or !istable(font_data) then return end
  if stored[name] then return end

  -- Force UTF-8 range by default.
  font_data.extended = true

  surface.CreateFont(name, font_data)
  stored[name] = font_data

  return stored[name]
end

--- Returns the name of the specified font scaled to the specified size. The sized font
-- is created from the original one on first use and is named 'name:size'.
-- ```
-- -- Creates 'flRobotoCondensed:24' if it does not exist yet.
-- local font = Font.size('flRobotoCondensed', 24)
-- ```
-- @param name [String name of a font created with Font.create]
-- @param size=nil [Number font size, the name is returned unchanged if omitted]
-- @param data=nil [Map extra font data to merge into the sized font]
-- @return [String name of the sized font, or false if no name was given]
function Font.size(name, size, data)
  if !size then return name end
  if !name then return false end

  local font = stored[name]

  if font and font.size == size then
    return name
  end

  local names_by_size = sized_names[name]

  if !names_by_size then
    names_by_size = {}
    sized_names[name] = names_by_size
  end

  local new_name = names_by_size[size]

  if !new_name then
    local raw_name, original_size = string.match(name, '^(.+):(%d)')

    new_name = (original_size and raw_name or name)..':'..size
    names_by_size[size] = new_name
  end

  if !stored[new_name] then
    local font_data = table.Copy(stored[name])

    if font_data then
      if !istable(data) then data = {} end

      font_data.size = size

      table.Merge(font_data, data)

      Font.create(new_name, font_data)
    end
  end

  return new_name
end

--- Forgets all of the created fonts, so that they can be created again.
function Font.clear()
  stored = {}
end

--- Returns the data of a font created with Font.create.
-- @param name [String]
-- @return [Map font data, or nil if there is no such font]
function Font.get(name)
  return stored[name]
end

--- Clears the stored fonts and creates the built-in Flux fonts again, then calls the
-- 'CreateFonts' theme and plugin hooks so that everything else can create theirs.
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
    weight = 1000
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
    weight = 1000
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
    weight = 1000
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
  --- Called on the client every time the fonts are created again: when the gamemode loads,
  -- once the schema has loaded and after a change of the screen resolution. The built-in fonts
  -- exist at this point and the `CreateFonts` theme hook of the active theme has run. Create
  -- your own fonts here with `Font.create`.
  hook.Run('CreateFonts')
end
