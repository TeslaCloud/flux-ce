do
  local cache = {}

  --- Measures the size a text takes up when drawn with the given font.
  -- Results are cached, so this is cheap to call every frame.
  -- @param text [String text to measure]
  -- @param font='default' [String font name]
  -- @return [Number width in pixels, Number height in pixels]
  function util.text_size(text, font)
    font = font or 'default'

    if cache[text] and cache[text][font] then
      local text_size = cache[text][font]

      return text_size[1], text_size[2]
    else
      surface.SetFont(font)

      local result = { surface.GetTextSize(text) }

      cache[text] = {}
      cache[text][font] = result

      return result[1], result[2]
    end
  end
end

--- Returns the width a text takes up when drawn with the given font.
-- @param text [String text to measure]
-- @param font='default' [String font name]
-- @return [Number width in pixels]
-- @see [util.text_size]
function util.text_width(text, font)
  return select(1, util.text_size(text, font))
end

--- Returns the height a text takes up when drawn with the given font.
-- @param text [String text to measure]
-- @param font='default' [String font name]
-- @return [Number height in pixels]
-- @see [util.text_size]
function util.text_height(text, font)
  return select(2, util.text_size(text, font))
end

--- Returns the line height of a font, measured on the sample text 'Agw'.
-- @param font='default' [String font name]
-- @return [Number height in pixels]
function util.font_size(font)
  return select(2, util.text_size('Agw', font))
end

--- Returns the class name a panel was registered under.
-- @param panel [Panel]
-- @return [String class name, or nil if the panel is invalid or has no ClassName]
function util.get_panel_class(panel)
  if panel and panel.GetTable then
    local panel_table = panel:GetTable()

    if panel_table and panel_table.ClassName then
      return panel_table.ClassName
    end
  end
end

--- Adjusts x, y to fit inside x2, y2 while keeping original aspect ratio.
-- @param x [Number width to fit]
-- @param y [Number height to fit]
-- @param x2 [Number maximum width]
-- @param y2 [Number maximum height]
-- @return [Number adjusted width, Number adjusted height]
function util.fit_to_aspect(x, y, x2, y2)
  local aspect = x / y

  if x > x2 then
    x = x2
    y = x * aspect
  end

  if y > y2 then
    y = y2
    x = y * aspect
  end

  return x, y
end

--- Calculates the value of a cubic ease-in interpolation at a given step.
-- @param cur_step [Number current step]
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [Number interpolated value]
function util.cubic_ease_in(cur_step, steps, from, to)
  return (to - from) * math.pow(cur_step / steps, 3) + from
end

--- Calculates the value of a cubic ease-out interpolation at a given step.
-- @param cur_step [Number current step]
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [Number interpolated value]
function util.cubic_ease_out(cur_step, steps, from, to)
  return (to - from) * (math.pow(cur_step / steps - 1, 3) + 1) + from
end

--- Precalculates every step of a cubic ease-in interpolation.
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [Array<Number> interpolated values, one per step]
-- @see [util.cubic_ease_in]
function util.cubic_ease_in_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    table.insert(result, util.cubic_ease_in(i, steps, from, to))
  end

  return result
end

--- Precalculates every step of a cubic ease-out interpolation.
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [Array<Number> interpolated values, one per step]
-- @see [util.cubic_ease_out]
function util.cubic_ease_out_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    table.insert(result, util.cubic_ease_out(i, steps, from, to))
  end

  return result
end

--- Calculates the value of a cubic ease-in-out interpolation at a given step.
-- Uses util.cubic_ease_in for the first half of the steps and util.cubic_ease_out for
-- the second half.
-- @param cur_step [Number current step]
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [Number interpolated value]
function util.cubic_ease_in_out(cur_step, steps, from, to)
  if cur_step > (steps * 0.5) then
    return util.cubic_ease_out(cur_step - steps * 0.5, steps * 0.5, from, to)
  else
    return util.cubic_ease_in(cur_step, steps, from, to)
  end
end

--- Precalculates every step of a cubic ease-in-out interpolation.
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [Array<Number> interpolated values, one per step]
-- @see [util.cubic_ease_in_out]
function util.cubic_ease_in_out_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    table.insert(result, util.cubic_ease_in_out(i, steps, from, to))
  end

  return result
end

do
  local mat_cache = {}

  --- Gets a material by its path. It caches the material automatically.
  -- @param mat [String material path]
  -- @return [Material]
  function util.get_material(mat)
    if !mat_cache[mat] then
      mat_cache[mat] = Material(mat)
    end

    return mat_cache[mat]
  end
end

do
  local cache = {}
  local loading_cache = {}

  --- Downloads an image from a URL into data/flux/materials and caches it as a material.
  -- The download is asynchronous: the OnURLMatLoaded hook runs with the URL and the material
  -- once it finishes. Images that were downloaded before are loaded from disk right away.
  -- @param url [String direct link to an image, has to end with a file extension]
  -- @see [URLMaterial]
  function util.cache_url_material(url)
    if isstring(url) and url != '' then
      local url_crc = util.CRC(url)
      local pieces = url:split('/')

      if istable(pieces) and #pieces > 0 then
        local extension = string.GetExtensionFromFilename(pieces[#pieces])

        if extension then
          extension = '.'..extension

          local path = 'flux/materials/'..url_crc..extension

          if _file.Exists(path, 'DATA') then
            cache[url_crc] = Material('../data/'..path, 'noclamp smooth')

            return
          end

          local directories = path:split('/')
          local current_path = ''

          for k, v in pairs(directories) do
            if k < #directories then
              current_path = current_path..v..'/'
              file.CreateDir(current_path)
            end
          end

          http.Fetch(url, function(body, length, headers, code)
            path = path:gsub('.jpeg', '.jpg')
            file.Write(path, body)
            cache[url_crc] = Material('../data/'..path, 'noclamp smooth')

            hook.run('OnURLMatLoaded', url, cache[url_crc])
          end)
        end
      end
    end
  end

  local placeholder = Material('vgui/wave')

  --- Returns the material of an image from a URL, starting the download on first use.
  -- A placeholder material is returned for as long as the image has not been loaded.
  -- @param url [String direct link to an image, has to end with a file extension]
  -- @return [Material the downloaded image, or a placeholder while it is loading]
  -- @see [util.cache_url_material]
  function URLMaterial(url)
    local url_crc = util.CRC(url)

    if cache[url_crc] then
      return cache[url_crc]
    end

    if !loading_cache[url_crc] then
      util.cache_url_material(url)
      loading_cache[url_crc] = true
    end

    return placeholder
  end
end

--- Splits a text into lines that fit into the given width when drawn with the given font.
-- Words that are wider than a whole line are broken up with a dash. Newlines are removed.
-- @param text [String text to wrap]
-- @param font [String font name]
-- @param width [Number maximum width of a line in pixels]
-- @param initial_width=0 [Number width that is already taken up on the first line]
-- @return [Array<String> lines, or nil if text, font or width is missing]
function util.wrap_text(text, font, width, initial_width)
  if !text or !font or !width then return end

  text = text:gsub('\n', '')

  local output = {}
  local space_width = util.text_size(' ', font)
  local dash_width = util.text_size('-', font)
  local pieces = text:split(' ')
  local cur_width = initial_width or 0
  local current_word = ''

  for k, v in ipairs(pieces) do
    local w, h = util.text_size(v, font)
    local remain = width - cur_width

    -- The width of the word is LESS OR EQUAL than what we have remaining.
    if w <= remain then
      if k != #pieces then
        current_word = current_word..v..' '
        cur_width = cur_width + w + space_width
      else
        current_word = current_word..v
        cur_width = cur_width + w
      end
    else -- The width of the word is MORE than what we have remaining.
      if w > width then -- The width is more than total width we have available.
        for i = 1, utf8.len(v) do
          local char = v:utf8sub(i, i)
          local char_width, _ = util.text_size(char, font)

          remain = width - cur_width

          if (char_width + dash_width + space_width) < remain then
            current_word = current_word..char
            cur_width = cur_width + char_width
          else
            current_word = current_word..char..'-'

            table.insert(output, current_word)

            current_word = ''
            cur_width = 0
          end
        end
      else -- The width is LESS than the total width
        table.insert(output, current_word)

        current_word = v..' '

        local wide = util.text_size(current_word, font)

        cur_width = wide
      end
    end
  end

  -- If we have some characters remaining, drop them into the lines table.
  if current_word != '' then
    table.insert(output, current_word)
  end

  return output
end
