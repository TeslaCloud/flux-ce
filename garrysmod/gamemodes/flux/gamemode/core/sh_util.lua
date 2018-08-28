AddCSLuaFile()

-- A function to get lowercase type of an object.
function typeof(obj)
  return string.lower(type(obj))
end

function Try(id, func, ...)
  id = id or "Try"
  local result = {pcall(func, ...)}
  local success = result[1]
  table.remove(result, 1)

  if (!success) then
    ErrorNoHalt("[Try:"..id.."] Failed to run the function!\n")
    ErrorNoHalt(unpack(result), "\n")
  elseif (result[1] != nil) then
    return unpack(result)
  end
end

do
  local tryCache = {}

  function try(tab)
    tryCache = {}
    tryCache.f = tab[1]

    local args = {}

    for k, v in ipairs(tab) do
      if (k != 1) then
        table.insert(args, v)
      end
    end

    tryCache.args = args
  end

  function catch(handler)
    local func = tryCache.f
    local args = tryCache.args or {}
    local result = {pcall(func, unpack(args))}
    local success = result[1]
    table.remove(result, 1)

    handler = handler or {}
    tryCache = {}

    SUCCEEDED = true

    if (!success) then
      SUCCEEDED = false

      if (isfunction(handler[1])) then
        handler[1](unpack(result))
      else
        ErrorNoHalt("[Try:Exception] Failed to run the function!\n")
        ErrorNoHalt(unpack(result), "\n")
      end
    elseif (result[1] != nil) then
      return unpack(result)
    end
  end

  --[[
    Please note that the try-catch block will only
    run if you put in the catch function.

    Example usage:

    try {
      function()
        print("Hello World")
      end
    } catch {
      function(exception)
        print(exception)
      end
    }

    try {
      function(arg1, arg2)
        print(arg1, arg2)
      end, "arg1", "arg2"
    } catch {
      function(exception)
        print(exception)
      end
    }
  --]]
end

do
  local vowels = {
    ["a"] = true,
    ["e"] = true,
    ["o"] = true,
    ["i"] = true,
    ["u"] = true,
    ["y"] = true,
  }

  -- A function to check whether character is vowel or not.
  function util.vowel(char)
    char = char:utf8lower()

    if CLIENT then
      local lang = fl.lang:GetTable(GetConVar("gmod_language"):GetString())

      if (lang and isfunction(lang.IsVowel)) then
        local override = lang:IsVowel(char)

        if (override != nil) then
          return override
        end
      end
    end

    return vowels[char]
  end
end

-- A function to remove a substring from the end of the string.
function string.trim_end(str, strNeedle, bAllOccurences)
  if (!strNeedle or strNeedle == "") then
    return str
  end

  if (str:EndsWith(strNeedle)) then
    if (bAllOccurences) then
      while (str:EndsWith(strNeedle)) do
        str = str:trim_end(strNeedle)
      end

      return str
    end

    return str:utf8sub(1, str:utf8len() - strNeedle:utf8len())
  else
    return str
  end
end

-- A function to remove a substring from the beginning of the string.
function string.trim_start(str, strNeedle, bAllOccurences)
  if (!strNeedle or strNeedle == "") then
    return str
  end

  if (str:StartWith(strNeedle)) then
    if (bAllOccurences) then
      while (str:StartWith(strNeedle)) do
        str = str:trim_start(strNeedle)
      end

      return str
    end

    return str:utf8sub(strNeedle:utf8len() + 1, str:utf8len())
  else
    return str
  end
end

function game.GetAmmoList()
  local ammoTable = {}
  local ammoID = 1

  while (game.GetAmmoName(ammoID) != nil) do
    ammoTable[ammoID] = game.GetAmmoName(ammoID)

    ammoID = ammoID + 1
  end

  return ammoTable
end

-- A function to check whether all of the arguments in vararg are valid (via IsValid).
function util.Validate(...)
  local validate = {...}

  if (#validate <= 0) then return false end

  for k, v in ipairs(validate) do
    if (!IsValid(v)) then
      return false
    end
  end

  return true
end

-- A function to include a file based on it's prefix.
function util.include(file_name)
  if SERVER then
    if (string.find(file_name, "cl_")) then
      AddCSLuaFile(file_name)
    elseif (string.find(file_name, "sv_") or string.find(file_name, "init.lua")) then
      return include(file_name)
    else
      AddCSLuaFile(file_name)

      return include(file_name)
    end
  else
    if (!string.find(file_name, "sv_") and file_name != "init.lua" and !file_name:EndsWith("/init.lua")) then
      return include(file_name)
    end
  end
end

-- A function to add a file to clientside downloads list based on it's prefix.
function util.AddCSLuaFile(strFile)
  if SERVER then
    if (string.find(strFile, "sh_") or string.find(strFile, "cl_") or string.find(strFile, "shared.lua")) then
      AddCSLuaFile(strFile)
    end
  end
end

-- A function to include all files in a directory.
function util.include_folder(strDirectory, strBase, bIsRecursive)
  if (strBase) then
    if (isbool(strBase)) then
      strBase = "flux/gamemode/"
    elseif (!strBase:EndsWith("/")) then
      strBase = strBase.."/"
    end

    strDirectory = strBase..strDirectory
  end

  if (!strDirectory:EndsWith("/")) then
    strDirectory = strDirectory.."/"
  end

  if (bIsRecursive) then
    local files, folders = _file.Find(strDirectory.."*", "LUA", "namedesc")

    -- First include the files.
    for k, v in ipairs(files) do
      if (v:GetExtensionFromFilename() == "lua") then
        util.include(strDirectory..v)
      end
    end

    -- Then include all directories.
    for k, v in ipairs(folders) do
      util.include_folder(strDirectory..v, bIsRecursive)
    end
  else
    local files, _ = _file.Find(strDirectory.."*.lua", "LUA", "namedesc")

    for k, v in ipairs(files) do
      util.include(strDirectory..v)
    end
  end
end

do
  local materialCache = {}

  -- A function to get a material. It caches the material automatically.
  function util.GetMaterial(mat)
    if (!materialCache[mat]) then
      materialCache[mat] = Material(mat)
    end

    return materialCache[mat]
  end
end

do
  local hexDigits = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}

  -- A function to convert a single hexadecimal digit to decimal.
  function util.HexToDec(hex)
    if (isnumber(hex)) then
      return hex
    end

    hex = hex:lower()

    local negative = false

    if (hex:StartWith("-")) then
      hex = hex:sub(2, 2)
      negative = true
    end

    for k, v in ipairs(hexDigits) do
      if (v == hex) then
        if (!negative) then
          return k - 1
        else
          return -(k - 1)
        end
      end
    end

    ErrorNoHalt("[util.HexToDec] '"..hex.."' is not a hexadecimal number!")

    return 0
  end
end

-- A function to convert hexadecimal number to decimal.
function util.HexToDecimal(hex)
  if (isnumber(hex)) then return hex end

  local sum = 0
  local chars = table.Reverse(string.Explode("", hex))
  local idx = 1

  for i = 0, hex:len() - 1 do
    sum = sum + util.HexToDec(chars[idx]) * math.pow(16, i)
    idx = idx + 1
  end

  return sum
end

-- A function to convert hexadecimal color to a color structure.
function util.HexToColor(hex)
  if (hex:StartWith("#")) then
    hex = hex:sub(2, hex:len())
  end

  local len = hex:len()

  if (len != 3 and len != 6 and len != 8) then
    return Color(255, 255, 255)
  end

  local hexColors = {}

  if (len == 3) then
    for i = 1, 3 do
      local v = hex[i]

      table.insert(hexColors, v..v) -- Duplicate the number.
    end
  else
    local initLen = len * 0.5

    for i = 1, len * 0.5 do
      table.insert(hexColors, hex:sub(1, 2))

      if (i != initLen) then
        hex = hex:sub(3, hex:len())
      end
    end
  end

  local color = {}

  for k, v in ipairs(hexColors) do
    table.insert(color, util.HexToDecimal(v))
  end

  return Color(color[1], color[2], color[3], (color[4] or 255))
end

do
  local colors = {
    aliceblue      = Color(240, 248, 255),
    antiquewhite    = Color(250, 235, 215),
    aqua        = Color(0, 255, 255),
    aquamarine      = Color(127, 255, 212),
    azure        = Color(240, 255, 255),
    beige        = Color(245, 245, 220),
    bisque        = Color(255, 228, 196),
    black        = Color(0, 0, 0),
    blanchedalmond    = Color(255, 235, 205),
    blue        = Color(0, 0, 255),
    blueviolet      = Color(138, 43, 226),
    brown        = Color(165, 42, 42),
    burlywood      = Color(222, 184, 135),
    cadetblue      = Color(95, 158, 160),
    chartreuse      = Color(127, 255, 0),
    chocolate      = Color(210, 105, 30),
    coral        = Color(255, 127, 80),
    cornflowerblue    = Color(100, 149, 237),
    cornsilk      = Color(255, 248, 220),
    crimson        = Color(220, 20, 60),
    cyan        = Color(0, 255, 255),
    darkblue      = Color(0, 0, 139),
    darkcyan      = Color(0, 139, 139),
    darkgoldenrod    = Color(184, 134, 11),
    darkgray      = Color(169, 169, 169),
    darkgreen      = Color(0, 100, 0),
    darkgrey      = Color(169, 169, 169),
    darkkhaki      = Color(189, 183, 107),
    darkmagenta      = Color(139, 0, 139),
    darkolivegreen    = Color(85, 107, 47),
    darkorange      = Color(255, 140, 0),
    darkorchid      = Color(153, 50, 204),
    darkred        = Color(139, 0, 0),
    darksalmon      = Color(233, 150, 122),
    darkseagreen    = Color(143, 188, 143),
    darkslateblue    = Color(72, 61, 139),
    darkslategray    = Color(47, 79, 79),
    darkslategrey    = Color(47, 79, 79),
    darkturquoise    = Color(0, 206, 209),
    darkviolet      = Color(148, 0, 211),
    deeppink      = Color(255, 20, 147),
    deepskyblue      = Color(0, 191, 255),
    dimgray        = Color(105, 105, 105),
    dimgrey        = Color(105, 105, 105),
    dodgerblue      = Color(30, 144, 255),
    firebrick      = Color(178, 34, 34),
    floralwhite      = Color(255, 250, 240),
    forestgreen      = Color(34, 139, 34),
    fuchsia        = Color(255, 0, 255),
    gainsboro      = Color(220, 220, 220),
    ghostwhite      = Color(248, 248, 255),
    gold        = Color(255, 215, 0),
    goldenrod      = Color(218, 165, 32),
    gray        = Color(128, 128, 128),
    grey        = Color(128, 128, 128),
    green        = Color(0, 128, 0),
    greenyellow      = Color(173, 255, 47),
    honeydew      = Color(240, 255, 240),
    hotpink        = Color(255, 105, 180),
    indianred      = Color(205, 92, 92),
    indigo        = Color(75, 0, 130),
    ivory        = Color(255, 255, 240),
    khaki        = Color(240, 230, 140),
    lavender      = Color(230, 230, 250),
    lavenderblush    = Color(255, 240, 245),
    lawngreen      = Color(124, 252, 0),
    lemonchiffon    = Color(255, 250, 205),
    lightblue      = Color(173, 216, 230),
    lightcoral      = Color(240, 128, 128),
    lightcyan      = Color(224, 255, 255),
    lightgoldenrodyellow  = Color(250, 250, 210), -- this color though
    lightgray      = Color(211, 211, 211),
    lightgreen      = Color(144, 238, 144),
    lightgrey      = Color(211, 211, 211),
    lightpink      = Color(255, 182, 193),
    lightsalmon      = Color(255, 160, 122),
    lightseagreen    = Color(32, 178, 170),
    lightskyblue    = Color(135, 206, 250),
    lightslategray    = Color(119, 136, 153),
    lightslategrey    = Color(119, 136, 153),
    lightsteelblue    = Color(176, 196, 222),
    lightyellow      = Color(255, 255, 224),
    lime        = Color(0, 255, 0),
    limegreen      = Color(50, 205, 50),
    linen        = Color(250, 240, 230),
    magenta        = Color(255, 0, 255),
    maroon        = Color(128, 0, 0),
    mediumaquamarine  = Color(102, 205, 170),
    mediumblue      = Color(0, 0, 205),
    mediumorchid    = Color(186, 85, 211),
    mediumpurple    = Color(147, 112, 219),
    mediumseagreen    = Color(60, 179, 113),
    mediumslateblue    = Color(123, 104, 238),
    mediumspringgreen  = Color(0, 250, 154),
    mediumturquoise    = Color(72, 209, 204),
    mediumvioletred    = Color(199, 21, 133),
    midnightblue    = Color(25, 25, 112),
    mintcream      = Color(245, 255, 250),
    mistyrose      = Color(255, 228, 225),
    moccasin      = Color(255, 228, 181),
    navajowhite      = Color(255, 222, 173),
    navy        = Color(0, 0, 128),
    oldlace        = Color(253, 245, 230),
    olive        = Color(128, 128, 0),
    olivedrab      = Color(107, 142, 35),
    orange        = Color(255, 165, 0),
    orangered      = Color(255, 69, 0),
    orchid        = Color(218, 112, 214),
    palegoldenrod    = Color(238, 232, 170),
    palegreen      = Color(152, 251, 152),
    paleturquoise    = Color(175, 238, 238),
    palevioletred    = Color(219, 112, 147),
    papayawhip      = Color(255, 239, 213),
    peachpuff      = Color(255, 218, 185),
    peru        = Color(205, 133, 63),
    pink        = Color(255, 192, 203),
    plum        = Color(221, 160, 221),
    powderblue      = Color(176, 224, 230),
    purple        = Color(128, 0, 128),
    red          = Color(255, 0, 0),
    rosybrown      = Color(188, 143, 143),
    royalblue      = Color(65, 105, 225),
    saddlebrown      = Color(139, 69, 19),
    salmon        = Color(250, 128, 114),
    sandybrown      = Color(244, 164, 96),
    seagreen      = Color(46, 139, 87),
    seashell      = Color(255, 245, 238),
    sienna        = Color(160, 82, 45),
    silver        = Color(192, 192, 192),
    skyblue        = Color(135, 206, 235),
    slateblue      = Color(106, 90, 205),
    slategray      = Color(112, 128, 144),
    slategrey      = Color(112, 128, 144),
    snow        = Color(255, 250, 250),
    springgreen      = Color(0, 255, 127),
    steelblue      = Color(70, 130, 180),
    tan          = Color(210, 180, 140),
    teal        = Color(0, 128, 128),
    thistle        = Color(216, 191, 216),
    tomato        = Color(255, 99, 71),
    turquoise      = Color(64, 224, 208),
    violet        = Color(238, 130, 238),
    wheat        = Color(245, 222, 179),
    white        = Color(255, 255, 255),
    whitesmoke      = Color(245, 245, 245),
    yellow        = Color(255, 255, 0),
    yellowgreen      = Color(154, 205, 50)
  }

  local oldColor = fl.oldColor or Color
  fl.oldColor = oldColor

  function Color(r, g, b, a)
    if (isstring(r)) then
      if (r:StartWith("#")) then
        return util.HexToColor(r)
      elseif (colors[r:lower()]) then
        return colors[r:lower()]
      else
        return Color(255, 255, 255)
      end
    else
      return oldColor(r, g, b, a)
    end
  end
end

-- A function to do C-style formatted prints.
function printf(str, ...)
  print(Format(str, ...))
end

-- A function to select a random player.
function player.Random()
  local allPly = player.GetAll()

  if (#allPly > 0) then
    return allPly[math.random(1, #allPly)]
  end
end

-- A function to find player based on their name or steam_id.
function player.Find(name, bCaseSensitive, bReturnFirstHit)
  if (name == nil) then return end
  if (!isstring(name)) then return (IsValid(name) and name) or nil end

  local hits = {}
  local isSteamID = name:StartWith("STEAM_")

  for k, v in ipairs(_player.GetAll()) do
    if (isSteamID) then
      if (v:SteamID() == name) then
        return v
      end

      continue
    end

    if (v:Name(true):find(name)) then
      table.insert(hits, v)
    elseif (!bCaseSensitive and v:Name(true):utf8lower():find(name:utf8lower())) then
      table.insert(hits, v)
    elseif (v:SteamName():utf8lower():find(name:utf8lower())) then
      table.insert(hits, v)
    end

    if (bReturnFirstHit and #hits > 0) then
      return hits[1]
    end
  end

  if (#hits > 1) then
    return hits
  else
    return hits[1]
  end
end

-- A function to check whether the string is full uppercase or not.
function string.IsUppercase(str)
  return string.utf8upper(str) == str
end

-- A function to check whether the string is full lowercase or not.
function string.IsLowercase(str)
  return string.utf8lower(str) == str
end

-- A function to find all occurences of a substring in a string.
function string.find_all(str, pattern)
  if (!str or !pattern) then return end

  local hits = {}
  local lastPos = 1

  while (true) do
    local startPos, end_pos = string.find(str, pattern, lastPos)

    if (!startPos) then
      break
    end

    table.insert(hits, {string.utf8sub(str, startPos, end_pos), startPos, end_pos})

    lastPos = end_pos + 1
  end

  return hits
end

-- A function to check if string is command or not.
function string.is_command(str)
  local prefixes = config.Get("command_prefixes") or {}

  for k, v in ipairs(prefixes) do
    if (str:StartWith(v) and hook.run("StringIsCommand", str) != false) then
      return true, string.utf8len(v)
    end
  end

  return false
end

do
  -- ID's should not have any of those characters.
  local blocked_chars = {
    "'", "\"", "\\", "/", "^",
    ":", ".", ";", "&", ",", "%"
  }

  function string.to_id(str)
    str = str:utf8lower()
    str = str:gsub(" ", "_")

    for k, v in ipairs(blocked_chars) do
      str = str:Replace(v, "")
    end

    return str
  end
end

do
  local cache = {}

  function util.text_size(text, font)
    font = font or "default"

    if (cache[text] and cache[text][font]) then
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
  if (panel and panel.GetTable) then
    local pTable = panel:GetTable()

    if (pTable and pTable.ClassName) then
      return pTable.ClassName
    end
  end
end

-- Adjusts x, y to fit inside x2, y2 while keeping original aspect ratio.
function util.fit_to_aspect(x, y, x2, y2)
  local aspect = x / y

  if (x > x2) then
    x = x2
    y = x * aspect
  end

  if (y > y2) then
    y = y2
    x = y * aspect
  end

  return x, y
end

function util.ToBool(value)
  return (tonumber(value) == 1 or value == true or value == "true")
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
  if (curStep > (steps * 0.5)) then
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

function util.wait_for_ent(entIndex, callback, delay, waitTime)
  local entity = Entity(entIndex)

  if (!IsValid(entity)) then
    local timerName = CurTime().."_EntWait"

    timer.Create(timerName, delay or 0, waitTime or 100, function()
      local entity = Entity(entIndex)

      if (IsValid(entity)) then
        callback(entity)

        timer.Remove(timerName)
      end
    end)
  else
    callback(entity)
  end
end

-- A function to determine whether vector from A to B intersects with a
-- vector from C to D.
function util.vectors_intersect(vFrom, vTo, vFrom2, vTo2)
  local d1, d2, a1, a2, b1, b2, c1, c2

  a1 = vTo.y - vFrom.y
  b1 = vFrom.x - vTo.x
  c1 = (vTo.x * vFrom.y) - (vFrom.x * vTo.y)

  d1 = (a1 * vFrom2.x) + (b1 * vFrom2.y) + c1
  d2 = (a1 * vTo2.x) + (b1 * vTo2.y) + c1

  if (d1 > 0 and d2 > 0) then return false end
  if (d1 < 0 and d2 < 0) then return false end

  a2 = vTo2.y - vFrom2.y
  b2 = vFrom2.x - vTo2.x
  c2 = (vTo2.x * vFrom2.y) - (vFrom2.x * vTo2.y)

  d1 = (a2 * vFrom.x) + (b2 * vFrom.y) + c2
  d2 = (a2 * vTo.x) + (b2 * vTo.y) + c2

  if (d1 > 0 and d2 > 0) then return false end
  if (d1 < 0 and d2 < 0) then return false end

  -- Vectors are collinear or intersect.
  -- No need for further checks.
  return true
end

-- A function to determine whether a 2D point is inside of a 2D polygon.
function util.vector_in_poly(point, polyVertices)
  if (!isvector(point) or !istable(polyVertices) or !isvector(polyVertices[1])) then
    return
  end

  local intersections = 0

  for k, v in ipairs(polyVertices) do
    local nextVert

    if (k < #polyVertices) then
      nextVert = polyVertices[k + 1]
    elseif (k == #polyVertices) then
      nextVert = polyVertices[1]
    end

    if (nextVert and util.vectors_intersect(point, Vector(99999, 99999, 0), v, nextVert)) then
      intersections = intersections + 1
    end
  end

  -- Check whether number of intersections is even or odd.
  -- If it's odd then the point is inside the polygon.
  if (intersections % 2 == 0) then
    return false
  else
    return true
  end
end

function table.safe_merge(to, from)
  local oldIndex, oldIndex2 = to.__index, from.__index
  local references = {}

  to.__index = nil
  from.__index = nil

  for k, v in pairs(from) do
    if v == from or k == 'class' then
      references[k] = v
      from[k] = nil
    end
  end

  table.Merge(to, from)

  for k, v in pairs(references) do
    from[k] = v
  end

  to.__index = oldIndex
  from.__index = oldIndex2

  return to
end

function util.ListToString(callback, separator, ...)
  if (!isfunction(callback)) then
    callback = function(obj) return tostring(obj) end
  end

  if (!isstring(separator)) then
    separator = ", "
  end

  local list = {...}
  local result = ""

  for k, v in ipairs(list) do
    local text = callback(v)

    if (isstring(text)) then
      result = result..text
    end

    if (k < #list) then
      result = result..separator
    end
  end

  return result
end

function util.PlayerListToString(...)
  local list = {...}
  local nlist = #list

  if (nlist > 1 and nlist == #_player.GetAll()) then
    return "#Chat_Everyone"
  end

  return util.ListToString(function(obj) return (IsValid(obj) and obj:Name()) or "Unknown Player" end, nil, ...)
end

function string.is_n(char)
  return tonumber(char) != nil
end

function string.count(str, char)
  local hits = 0

  for i = 1, str:len() do
    if str[i] == char then
      hits = hits + 1
    end
  end

  return hits
end

function string.Spelling(str)
  local len = str:utf8len()
  local end_text = str:utf8sub(-1)

  str = str:utf8sub(1, 1):utf8upper()..str:utf8sub(2, len)

  if ((end_text != ".") and (end_text != "!") and (end_text != "?") and ((end_text != '"'))) then
    str = str.."."
  end

  return str
end

function util.remove_newlines(str)
  local exploded = string.Explode("", str)
  local to_ret = ""
  local skip = ""

  for k, v in ipairs(exploded) do
    if (skip != "") then
      to_ret = to_ret..v

      if (v == skip) then
        skip = ""
      end

      continue
    end

    if (v == "\"") then
      skip = "\""

      to_ret = to_ret..v

      continue
    end

    if (v == "\n" or v == "\t") then
      continue
    end

    to_ret = to_ret..v
  end

  return to_ret
end

function util.table_from_string(str)
  str = util.remove_newlines(str)

  local exploded = string.Explode(",", str)
  local tab = {}

  for k, v in ipairs(exploded) do
    if (!isstring(v)) then continue end

    if (!string.find(v, "=")) then
      v = v:trim_start(" ", true)

      if (string.is_n(v)) then
        v = tonumber(v)
      elseif (string.find(v, "\"")) then
        v = v:trim_start("\""):trim_end("\"")
      elseif (v:find("{")) then
        v = v:Replace("{", "")

        local last_key = nil
        local buff = v

        for k2, v2 in ipairs(exploded) do
          if (k2 <= k) then continue end

          if (v2:find("}")) then
            buff = buff..","..v2:Replace("}", "")

            last_key = k2

            break
          end

          buff = buff..","..v2
        end

        if (last_key) then
          for i = k, last_key do
            exploded[i] = nil
          end

          v = util.table_from_string(buff)
        end
      else
        v = v:trim_end("}")
      end

      v = v:trim_end("}")
      v = v:trim_end("\"")

      table.insert(tab, v)
    else
      local parts = string.Explode("=", v)
      local key = parts[1]:trim_end(" ", true):trim_end("\t", true)
      local value = parts[2]:trim_start(" ", true):trim_start("\t", true)

      if (string.is_n(value)) then
        value = tonumber(value)
      elseif (value:find("{") and value:find("}")) then
        value = util.table_from_string(value)
      else
        value = value:trim_end("}")
      end

      tab[key] = value
    end
  end

  return tab
end

function util.RemoveFunctions(obj)
  if (istable(obj)) then
    for k, v in pairs(obj) do
      if (isfunction(v)) then
        obj[k] = nil
      elseif (istable(v)) then
        obj[k] = util.RemoveFunctions(v)
      end
    end
  end

  return obj
end

local color_meta = FindMetaTable("Color")

do
  local _r = 0.299
  local _g = 0.587
  local _b = 0.114

  -- A function to saturate the color.
  -- Ripped directly from C equivalent code that can be found
  -- here: http://alienryderflex.com/saturation.html
  function color_meta:saturation(amt)
    local r, g, b = self.r, self.g, self.b
    local p = math.sqrt((r * r * _r) + (g * g * _g) + (b * b + _b))

    return Color(
      math.Clamp(p + (r - p) * amt, 0, 255),
      math.Clamp(p + (g - p) * amt, 0, 255),
      math.Clamp(p + (b - p) * amt, 0, 255),
      self.a
    )
  end

  function color_meta:saturate(percentage)
    return self:saturation(1 + percentage / 100)
  end

  function color_meta:desaturate(percentage)
    return self:saturation(1 - math.Clamp(percentage, 0, 100) / 100)
  end
end

function color_meta:darken(amt)
  return Color(
    math.Clamp(self.r - amt, 0, 255),
    math.Clamp(self.g - amt, 0, 255),
    math.Clamp(self.b - amt, 0, 255),
    self.a
  )
end

function color_meta:lighten(amt)
  return Color(
    math.Clamp(self.r + amt, 0, 255),
    math.Clamp(self.g + amt, 0, 255),
    math.Clamp(self.b + amt, 0, 255),
    self.a
  )
end

if CLIENT then
  local loading_cache = {}

  function util.CacheURLMaterial(url)
    if (isstring(url) and url != "") then
      local url_crc = util.CRC(url)
      local exploded = string.Explode("/", url)

      if (istable(exploded) and #exploded > 0) then
        local extension = string.GetExtensionFromFilename(exploded[#exploded])

        if (extension) then
          local extension = "."..extension
          local path = "flux/materials/"..url_crc..extension

          if (_file.Exists(path, "DATA")) then
            cache[url_crc] = Material("../data/"..path, "noclamp smooth")

            return
          end

          local directories = string.Explode("/", path)
          local currentPath = ""

          for k, v in pairs(directories) do
            if (k < #directories) then
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

    if (cache[url_crc]) then
      return cache[url_crc]
    end

    if (!loading_cache[url_crc]) then
      util.CacheURLMaterial(url)
      loading_cache[url_crc] = true
    end

    return placeholder
  end

  function util.WrapText(text, font, width, initial_width)
    if (!text or !font or !width) then return end

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
      if (w <= remain) then
        current_word = current_word..v.." "
        cur_width = cur_width + w + spaceWidth
      else -- The width of the word is MORE than what we have remaining.
        if (w > width) then -- The width is more than total width we have available.
          for _, v2 in ipairs(string.Explode("", v)) do
            local char_width, _ = util.text_size(v2, font)

            remain = width - cur_width

            if ((char_width + dashWidth + spaceWidth) < remain) then
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
    if (current_word != "") then
      table.insert(output, current_word)
    end

    return output
  end
end

function util.text_color_from_base(base_color)
  local average = (base_color.r + base_color.g + base_color.b) / 3

  if (average > 125) then
    return Color(0, 0, 0)
  else
    return Color(255, 255, 255)
  end
end

-- Add the ability to join strings with + assistant.
local stringMeta = getmetatable("")

function stringMeta:__add(right)
  return self..tostring(right)
end

function string.trim(...)
  return string.Trim(...)
end

function string.starts(...)
  return string.StartWith(...)
end

function string.ends(...)
  return string.EndsWith(...)
end

function string.presence(str)
  return isstring(str) and (str != '' and str) or nil
end

function string.to_snake_case(str)
  str = str[1]:lower()..str:sub(2, str:len())

  return str:gsub('([a-z])([A-Z])', function(lower, upper)
    return lower..'_'..string.lower(upper)
  end):lower()
end

function string.snake_to_pascal_case(str)
  str = str[1]:upper()..str:sub(2, str:len())

  return str:gsub('_([a-z])', string.upper)
end

function string.chomp(str, what)
  if !what then
    str = str:trim_end("\n", true):trim_end("\r", true)
  else
    str = str:trim_start(what, true):trim_end(what, true)
  end
  return str
end

function string.capitalize(str)
  local len = string.utf8len(str)
  return string.utf8upper(str[1])..(len > 1 and string.utf8sub(str, 2, string.utf8len(str)) or '')
end

function string.parse_table(str)
  local tables = string.Explode('::', str)
  local ref = _G
  for k, v in ipairs(tables) do
    ref = ref[v]
    if !istable(ref) then return false, v end
  end
  return ref
end

function string.parse_parent(str)
  local tables = string.Explode('::', str)
  local ref = _G
  for k, v in ipairs(tables) do
    local new_ref = ref[v]
    if !istable(new_ref) then return ref, v end
    ref = new_ref
  end
  if istable(ref) then
    return ref, str
  else
    return false
  end
end

function table.map(t, c)
  local new_table = {}

  for k, v in pairs(t) do
    local val = c(v)
    if val != nil then
      table.insert(new_table, val)
    end
  end

  return new_table
end

function table.map_kv(t, c)
  local new_table = {}

  for k, v in pairs(t) do
    local val = c(k, v)
    if val != nil then
      table.insert(new_table, val)
    end
  end

  return new_table
end

function table.select(t, what)
  local new_table = {}

  for k, v in pairs(t) do
    if istable(v) then
      table.insert(new_table, v[what])
    end
  end

  return new_table
end

function table.slice(t, from, to)
  local new_table = {}
  for i = from, to do
    table.insert(new_table, t[i])
  end
  return new_table
end

do
  local table_meta = {
    __index = table
  }

  -- Special arrays.
  function a(initializer)
    return setmetatable(initializer, table_meta)
  end

  function is_a(obj)
    return getmetatable(obj) == table_meta
  end
end

-- For use with table#map
-- table.map(t, s'some_field')
function s(what)
  return function(tab)
    return tab[what]
  end
end

function txt(text)
  local lines = string.Explode('\n', (text or ''):chomp('\n'))
  local lowest_indent
  local output = ''
  for k, v in ipairs(lines) do
    if v:match('^[%s]+$') then continue end
    local indent = v:match('^([%s]+)')
    if !indent then continue end
    if !lowest_indent then lowest_indent = indent end
    if indent:len() < lowest_indent:len() then
      lowest_indent = indent
    end
  end
  for k, v in ipairs(lines) do
    output = output..v:trim_start(lowest_indent)..'\n'
  end
  return output:chomp(' '):chomp('\n')
end
