do
  local cache = {}

  function util.text_size(text, font)
    font = font or "default"

    if cache[text] and cache[text][font] then
      local text_size = cache[text][font]

      return text_size[1], text_size[2]
    else
      surface.SetFont(font)

      local result = {surface.GetTextSize(text)}

      cache[text] = {}
      cache[text][font] = result

      return result[1], result[2]
    end
  end
end

function util.text_width(text, font)
  return select(1, util.text_size(text, font))
end

function util.text_height(text, font)
  return select(2, util.text_size(text, font))
end

function util.font_size(font)
  return select(2, util.text_size("Agw", font))
end

function util.get_panel_class(panel)
  if panel and panel.GetTable then
    local pTable = panel:GetTable()

    if pTable and pTable.ClassName then
      return pTable.ClassName
    end
  end
end

-- Adjusts x, y to fit inside x2, y2 while keeping original aspect ratio.
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

function util.cubic_ease_in(curStep, steps, from, to)
  return (to - from) * math.pow(curStep / steps, 3) + from
end

function util.cubic_ease_out(curStep, steps, from, to)
  return (to - from) * (math.pow(curStep / steps - 1, 3) + 1) + from
end

function util.cubic_ease_in_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    table.insert(result, util.cubic_ease_in(i, steps, from, to))
  end

  return result
end

function util.cubic_ease_out_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    table.insert(result, util.cubic_ease_out(i, steps, from, to))
  end

  return result
end

function util.cubic_ease_in_out(curStep, steps, from, to)
  if curStep > (steps * 0.5) then
    return util.cubic_ease_out(curStep - steps * 0.5, steps * 0.5, from, to)
  else
    return util.cubic_ease_in(curStep, steps, from, to)
  end
end

function util.cubic_ease_in_out_t(steps, from, to)
  local result = {}

  for i = 1, steps do
    table.insert(result, util.cubic_ease_in_out(i, steps, from, to))
  end

  return result
end

do
  local mat_cache = {}

  -- A function to get a material. It caches the material automatically.
  function util.get_material(mat)
    if !mat_cache[mat] then
      mat_cache[mat] = Material(mat)
    end

    return mat_cache[mat]
  end
end

local loading_cache = {}

function util.cache_url_material(url)
  if isstring(url) and url != "" then
    local url_crc = util.CRC(url)
    local exploded = string.Explode("/", url)

    if istable(exploded) and #exploded > 0 then
      local extension = string.GetExtensionFromFilename(exploded[#exploded])

      if extension then
        local extension = "."..extension
        local path = "flux/materials/"..url_crc..extension

        if _file.Exists(path, "DATA") then
          cache[url_crc] = Material("../data/"..path, "noclamp smooth")

          return
        end

        local directories = string.Explode("/", path)
        local currentPath = ""

        for k, v in pairs(directories) do
          if k < #directories then
            currentPath = currentPath..v.."/"
            file.CreateDir(currentPath)
          end
        end

        http.Fetch(url, function(body, length, headers, code)
          path = path:gsub(".jpeg", ".jpg")
          file.Write(path, body)
          cache[url_crc] = Material("../data/"..path, "noclamp smooth")

          hook.run("OnURLMatLoaded", url, cache[url_crc])
        end)
      end
    end
  end
end

local placeholder = Material("vgui/wave")

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

function util.wrap_text(text, font, width, initial_width)
  if !text or !font or !width then return end

  local output = {}
  local spaceWidth = util.text_size(" ", font)
  local dashWidth = util.text_size("-", font)
  local exploded = string.Explode(" ", text)
  local cur_width = initial_width or 0
  local current_word = ""

  for k, v in ipairs(exploded) do
    local w, h = util.text_size(v, font)
    local remain = width - cur_width

    -- The width of the word is LESS OR EQUAL than what we have remaining.
    if w <= remain then
      current_word = current_word..v.." "
      cur_width = cur_width + w + spaceWidth
    else -- The width of the word is MORE than what we have remaining.
      if w > width then -- The width is more than total width we have available.
        for _, v2 in ipairs(string.Explode("", v)) do
          local char_width, _ = util.text_size(v2, font)

          remain = width - cur_width

          if (char_width + dashWidth + spaceWidth) < remain then
            current_word = current_word..v2
            cur_width = cur_width + char_width
          else
            current_word = current_word..v2.."-"

            table.insert(output, current_word)

            current_word = ""
            cur_width = 0
          end
        end
      else -- The width is LESS than the total width
        table.insert(output, current_word)

        current_word = v.." "

        local wide = util.text_size(current_word, font)

        cur_width = wide
      end
    end
  end

  -- If we have some characters remaining, drop them into the lines table.
  if current_word != "" then
    table.insert(output, current_word)
  end

  return output
end
