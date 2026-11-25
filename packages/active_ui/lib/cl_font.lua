--- Creates and keeps track of the fonts of the Flux interface. `Font.create` wraps
-- `surface.CreateFont` and remembers the data of the font, which lets `Font.size` derive a
-- copy of any created font at another size on demand (named 'name:size', with the extra font
-- data appended when there is any), so that the interface can ask for a scaled font wherever
-- it draws text. All fonts are created by `Font.create_fonts` once the schema has loaded on
-- the client and again whenever the screen resolution changes. It creates the built-in
-- Roboto family ('flRoboto', 'flRobotoCondensed' and so on) and then runs the `RegisterFonts`
-- theme hook and the `RegisterFonts` hook. Plugins create their fonts from a `RegisterFonts`
-- handler so that they survive these rebuilds, and themes give fonts a role with
-- `ThemeBase:set_font`, which the interface looks up with `Theme.get_font`.

mod 'Font'

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

  font_data.extended = true

  surface.CreateFont(name, font_data)
  stored[name] = font_data

  return stored[name]
end

--- Builds the part of the name of a sized font that tells its extra font data apart: the
-- sorted 'key=value' pairs of the data after a colon, or an empty string without data.
-- @param data [Map/Nil extra font data]
-- @return [String]
local function data_suffix(data)
  if !istable(data) or next(data) == nil then return '' end

  local keys = table.GetKeys(data)
  local parts = {}

  table.sort(keys, |a, b| -> tostring(a) < tostring(b))

  for i = 1, #keys do
    local key = keys[i]

    parts[i] = tostring(key)..'='..tostring(data[key])
  end

  return ':'..table.concat(parts, ',')
end

--- Returns the name of the specified font scaled to the specified size. The sized font
-- is created from the original one on first use and is named 'name:size', followed by the
-- sorted extra data when there is any ('name:size:key=value,key=value'), so that two calls
-- with different data never share a font. A font sized from a font that `Font.create_fonts`
-- has not created again yet is derived from the base font of that sized font.
-- ```
-- -- Creates 'flRobotoCondensed:24' if it does not exist yet.
-- local font = Font.size('flRobotoCondensed', 24)
--
-- -- Creates 'flRoboto:14:weight=600'.
-- local bold = Font.size('flRoboto', 14, { weight = 600 })
-- ```
-- @param name [String name of a font created with Font.create]
-- @param size=nil [Number font size, the name is returned unchanged if omitted]
-- @param data=nil [Map extra font data to merge into the sized font]
-- @return [String name of the sized font, or false if no name was given]
function Font.size(name, size, data)
  if !size then return name end
  if !name then return false end

  local suffix = data_suffix(data)
  local font = stored[name]

  if suffix == '' and font and font.size == size then
    return name
  end

  local names_by_size = sized_names[name]

  if !names_by_size then
    names_by_size = {}
    sized_names[name] = names_by_size
  end

  local key = suffix == '' and size or size..suffix
  local new_name = names_by_size[key]

  if !new_name then
    new_name = (string.match(name, '^(.+):%d+$') or name)..':'..size..suffix
    names_by_size[key] = new_name
  end

  if !stored[new_name] then
    local source = font

    if !source then
      local raw_name = string.match(name, '^(.+):%d+$')

      source = raw_name and stored[raw_name]
    end

    if source then
      local font_data = table.Copy(source)

      font_data.size = size

      if suffix != '' then
        table.Merge(font_data, data)
      end

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
-- 'RegisterFonts' theme and plugin hooks so that everything else can create theirs.
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

  Theme.hook('RegisterFonts')
  --- Called on the client every time the fonts are created again: when the gamemode loads,
  -- once the schema has loaded and after a change of the screen resolution. The built-in fonts
  -- exist at this point and the `RegisterFonts` theme hook of the active theme has run. Create
  -- your own fonts here with `Font.create`.
  hook.Run('RegisterFonts')
end
