--- Client side of the `util` extensions: measuring and wrapping text, building menus out of
-- lists of options, cubic easing, cached materials and materials downloaded from a URL.

local pow = math.pow
local set_font = surface.SetFont
local get_text_size = surface.GetTextSize

do
  local cache = {}
  local cache_size = 0
  local max_cache_size = 8192

  --- Measures the size a text takes up when drawn with the given font.
  -- Results are cached, so this is cheap to call every frame. The cache is emptied once it
  -- holds results for more than 8192 different texts.
  -- @param text [String text to measure]
  -- @param font='default' [String font name]
  -- @return [Number width in pixels, Number height in pixels]
  function util.text_size(text, font)
    font = font or 'default'

    local text_cache = cache[text]
    local text_size = text_cache and text_cache[font]

    if text_size then
      return text_size[1], text_size[2]
    else
      set_font(font)

      local width, height = get_text_size(text)

      if !text_cache then
        if cache_size >= max_cache_size then
          cache = {}
          cache_size = 0
        end

        text_cache = {}
        cache[text] = text_cache
        cache_size += 1
      end

      text_cache[font] = { width, height }

      return width, height
    end
  end
end

--- Returns the width a text takes up when drawn with the given font.
-- @param text [String text to measure]
-- @param font='default' [String font name]
-- @return [Number width in pixels]
-- @see [util.text_size]
function util.text_width(text, font)
  return (util.text_size(text, font))
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

--- Builds a `DermaMenu` out of a list of options, in order. An option with an `options` list
-- becomes a submenu that holds those options; any other option runs its `callback` when it
-- is chosen. The `id` of an option is not shown: it lets code find the option in the list.
-- ```
-- util.build_menu({
--   { id = 'wave', text = t'ui.my_plugin.wave', icon = 'icon16/user.png', callback = wave },
--   { id = 'more', text = t'ui.my_plugin.more', options = {
--     { id = 'poke', text = t'ui.my_plugin.poke', callback = poke }
--   } }
-- }):Open()
-- ```
-- @param options [List<Map> options with id (String), text (String shown as it is), icon
--   (String material path, optional) and either callback (Function) or options (List of the
--   options of a submenu)]
-- @param menu=DermaMenu() [Panel menu or submenu to add the options to]
-- @return [Panel the menu]
function util.build_menu(options, menu)
  menu = menu or DermaMenu()

  for _, option in ipairs(options) do
    local option_panel

    if option.options then
      local submenu

      submenu, option_panel = menu:AddSubMenu(option.text)

      util.build_menu(option.options, submenu)
    else
      option_panel = menu:AddOption(option.text, option.callback)
    end

    if option.icon then
      option_panel:SetIcon(option.icon)
    end
  end

  return menu
end

--- Adjusts x, y to fit inside x2, y2 while keeping the original aspect ratio.
-- @param x [Number width to fit]
-- @param y [Number height to fit]
-- @param x2 [Number maximum width]
-- @param y2 [Number maximum height]
-- @return [Number adjusted width, Number adjusted height]
function util.fit_to_aspect(x, y, x2, y2)
  local aspect = x / y

  if x > x2 then
    x = x2
    y = x / aspect
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
  return (to - from) * pow(cur_step / steps, 3) + from
end

--- Calculates the value of a cubic ease-out interpolation at a given step.
-- @param cur_step [Number current step]
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [Number interpolated value]
function util.cubic_ease_out(cur_step, steps, from, to)
  return (to - from) * (pow(cur_step / steps - 1, 3) + 1) + from
end

--- Precalculates every step of a cubic ease-in interpolation.
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [List<Number> interpolated values, one per step]
-- @see [util.cubic_ease_in]
function util.cubic_ease_in_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    result[i] = util.cubic_ease_in(i, steps, from, to)
  end

  return result
end

--- Precalculates every step of a cubic ease-out interpolation.
-- @param steps [Number total amount of steps]
-- @param from [Number starting value]
-- @param to [Number final value]
-- @return [List<Number> interpolated values, one per step]
-- @see [util.cubic_ease_out]
function util.cubic_ease_out_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    result[i] = util.cubic_ease_out(i, steps, from, to)
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
-- @return [List<Number> interpolated values, one per step]
-- @see [util.cubic_ease_in_out]
function util.cubic_ease_in_out_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    result[i] = util.cubic_ease_in_out(i, steps, from, to)
  end

  return result
end

do
  local mat_cache = {}

  --- Gets a material by its path. It caches the material automatically, once per path and
  -- set of PNG parameters.
  -- @param mat [String material path]
  -- @param png_parameters [String PNG parameters such as 'smooth mips', default: none]
  -- @return [Material]
  function util.get_material(mat, png_parameters)
    local key = png_parameters and mat..'\0'..png_parameters or mat
    local material = mat_cache[key]

    if !material then
      material = Material(mat, png_parameters)
      mat_cache[key] = material
    end

    return material
  end
end

do
  local cache = {}
  local loading_cache = {}

  --- Downloads an image from a URL into data/flux/materials and caches it as a material.
  -- The download is asynchronous: the URLMaterialLoaded hook runs with the URL and the material
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

          local path = ('flux/materials/'..url_crc..extension):gsub('%.jpeg$', '.jpg')

          if file.Exists(path, 'DATA') then
            cache[url_crc] = Material('../data/'..path, 'noclamp smooth')

            return
          end

          local directories = path:split('/')

          for index = 1, #directories - 1 do
            file.CreateDir(table.concat(directories, '/', 1, index))
          end

          http.Fetch(url, function(body, _length, _headers, code)
            if code < 200 or code >= 300 then return end

            file.Write(path, body)
            cache[url_crc] = Material('../data/'..path, 'noclamp smooth')

            --- Called on the client when an image requested with `URLMaterial` or
            -- `util.cache_url_material` has been downloaded and turned into a material.
            -- Images that are on disk already are loaded without running this hook.
            -- @param url [String URL the image was downloaded from]
            -- @param material [Material the downloaded image]
            hook.Run('URLMaterialLoaded', url, cache[url_crc])
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
    local material = cache[url_crc]

    if material then
      return material
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
-- @return [List<String> lines, or nil if text, font or width is missing]
function util.wrap_text(text, font, width, initial_width)
  if !text or !font or !width then return end

  text = text:gsub('\n', '')

  local output = {}
  local space_width = util.text_size(' ', font)
  local dash_width = util.text_size('-', font)
  local pieces = text:split(' ')
  local cur_width = initial_width or 0
  local line = {}

  for index, word in ipairs(pieces) do
    local word_width = util.text_size(word, font)
    local remain = width - cur_width

    if word_width <= remain then
      line[#line + 1] = word

      if index != #pieces then
        line[#line + 1] = ' '
        cur_width = cur_width + word_width + space_width
      else
        cur_width += word_width
      end
    elseif word_width > width then
      for i = 1, utf8.len(word) do
        local char = word:utf8sub(i, i)
        local char_width = util.text_size(char, font)

        remain = width - cur_width
        line[#line + 1] = char

        if (char_width + dash_width + space_width) < remain then
          cur_width += char_width
        else
          line[#line + 1] = '-'
          output[#output + 1] = table.concat(line)

          line = {}
          cur_width = 0
        end
      end
    else
      output[#output + 1] = table.concat(line)

      line = { word, ' ' }
      cur_width = util.text_size(word..' ', font)
    end
  end

  local rest = table.concat(line)

  if rest != '' then
    output[#output + 1] = rest
  end

  return output
end
