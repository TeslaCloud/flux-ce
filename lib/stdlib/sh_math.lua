--- Extensions of the `math` library: snake_case aliases for the built-in functions, scaling of
-- sizes to the screen resolution and checks for even, odd and divisible numbers.
-- Numbers get the `math` library as their methods here, so that `n:floor()` and
-- `n:clamp(0, 3)` work. The `Time` and `Unit` classes add their constructors and converters
-- to the library as well, as in `math.minutes(5)` and `math.meters(2)`. This file also defines
-- the `util` functions for hexadecimal numbers and 2D geometry.
-- @module [math]

-- Ruby-style names for the built-in math functions.
math.angle_difference = math.AngleDifference
math.approach         = math.Approach
math.approach_angle   = math.ApproachAngle
math.bin_to_int       = math.BinToInt
math.bspline_point    = math.BSplinePoint
math.clamp            = math.Clamp
math.dist             = math.Dist
math.distance         = math.Distance
math.ease_in_out      = math.EaseInOut
math.int_to_bin       = math.IntToBin
math.normalize_angle  = math.NormalizeAngle
math.rand             = math.Rand
math.remap            = math.Remap
math.round            = math.Round
math.time_fraction    = math.TimeFraction
math.truncate         = math.Truncate

do
  local hex_digits = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' }

  --- Converts a single hexadecimal digit to decimal.
  -- @param hex [String/Number hexadecimal digit, may be prefixed with '-'; numbers pass through]
  -- @return [Number decimal value, or 0 (after printing an error) if it is not a hexadecimal digit]
  function util.hex_to_decimal(hex)
    if isnumber(hex) then
      return hex
    end

    hex = hex:lower()

    local negative = false

    if hex:start_with('-') then
      hex = hex:sub(2, 2)
      negative = true
    end

    for k, v in ipairs(hex_digits) do
      if v == hex then
        if !negative then
          return k - 1
        else
          return -(k - 1)
        end
      end
    end

    ErrorNoHalt("hex_to_dec - '"..hex.."' is not a hexadecimal number!")

    return 0
  end
end

--- Converts a hexadecimal number to decimal.
-- @param hex [String/Number hexadecimal number without a prefix, e.g. 'ff'; numbers pass through]
-- @return [Number decimal value]
function util.hex_to_dec(hex)
  if isnumber(hex) then return hex end

  local sum = 0
  local chars = table.Reverse(hex:split())
  local idx = 1

  for i = 0, hex:len() - 1 do
    sum = sum + util.hex_to_decimal(chars[idx]) * math.pow(16, i)
    idx = idx + 1
  end

  return sum
end

--- Determines whether a vector from A to B intersects with a vector from C to D.
-- Works in 2D, only the x and y components are used.
-- @param from [Vector point A]
-- @param to [Vector point B]
-- @param from2 [Vector point C]
-- @param to2 [Vector point D]
-- @return [Boolean true if the vectors intersect or are collinear]
function util.vectors_intersect(from, to, from2, to2)
  local d1, d2, a1, a2, b1, b2, c1, c2

  a1 = to.y - from.y
  b1 = from.x - to.x
  c1 = (to.x * from.y) - (from.x * to.y)

  d1 = (a1 * from2.x) + (b1 * from2.y) + c1
  d2 = (a1 * to2.x) + (b1 * to2.y) + c1

  if d1 > 0 and d2 > 0 then return false end
  if d1 < 0 and d2 < 0 then return false end

  a2 = to2.y - from2.y
  b2 = from2.x - to2.x
  c2 = (to2.x * from2.y) - (from2.x * to2.y)

  d1 = (a2 * from.x) + (b2 * from.y) + c2
  d2 = (a2 * to.x) + (b2 * to.y) + c2

  if d1 > 0 and d2 > 0 then return false end
  if d1 < 0 and d2 < 0 then return false end

  -- Vectors are collinear or intersect.
  -- No need for further checks.
  return true
end

--- Determines whether a 2D point is inside of a 2D polygon.
-- @param point [Vector point to check, only x and y are used]
-- @param poly_vertices [List<Vector> vertices of the polygon, in order]
-- @return [Boolean whether the point is inside, or nil if the arguments are invalid]
function util.vector_in_poly(point, poly_vertices)
  if !isvector(point) or !istable(poly_vertices) or !isvector(poly_vertices[1]) then
    return
  end

  local intersections = 0

  for k, v in ipairs(poly_vertices) do
    local next_vert

    if k < #poly_vertices then
      next_vert = poly_vertices[k + 1]
    elseif k == #poly_vertices then
      next_vert = poly_vertices[1]
    end

    if next_vert and util.vectors_intersect(point, Vector(99999, 99999, 0), v, next_vert) then
      intersections = intersections + 1
    end
  end

  -- Check whether the number of intersections is even or odd.
  -- If it's odd then the point is inside the polygon.
  if intersections % 2 == 0 then
    return false
  else
    return true
  end
end

do
  local scale_factor_x = 1 / 1920
  local scale_factor_y = 1 / 1080

  --- Scales a size that was designed for a 1080 pixels tall screen to the current screen height.
  -- Clientside only, since it depends on the screen resolution.
  -- @param size [Number size at 1080p]
  -- @return [Number scaled size, rounded down]
  function math.scale(size)
    return math.floor(size * (ScrH() * scale_factor_y))
  end

  --- Scales a size that was designed for a 1920 pixels wide screen to the current screen width.
  -- Clientside only, since it depends on the screen resolution.
  -- @param size [Number size at 1920 pixels of width]
  -- @return [Number scaled size, rounded down]
  function math.scale_x(size)
    return math.floor(size * (ScrW() * scale_factor_x))
  end

  --- Scales a width and a height that were designed for a 1920x1080 screen to the current
  -- screen resolution. Clientside only.
  -- @param x [Number width at 1920x1080]
  -- @param y [Number height at 1920x1080]
  -- @return [Number scaled width, Number scaled height]
  function math.scale_size(x, y)
    return math.scale_x(x), math.scale(y)
  end

  math.scale_y      = math.scale
  math.scale_width  = math.scale_x
  math.scale_height = math.scale
end

--- Checks whether a number is even.
-- @param num [Number]
-- @return [Boolean]
function math.even(num)
  return num % 2 == 0
end

--- Checks whether a number is odd.
-- @param num [Number]
-- @return [Boolean]
function math.odd(num)
  return num % 2 != 0
end

--- Checks whether a number is divisible by another number without a remainder.
-- @param num [Number]
-- @param factor [Number divisor]
-- @return [Boolean]
function math.divisible(num, factor)
  return num % factor == 0
end

math.divisible_by = math.divisible

--- Allows math.* methods to be called on number literals.
local number_meta = debug.getmetatable(0) or {}

--- Looks up the keys that are indexed on a number in the math library, so that its functions
-- can be called as methods. Throws an error if the math library has no such key.
-- ```
-- local n = 12.7
-- print(n:floor()) -- 12, same as math.floor(n)
-- ```
-- @param key [String name of a math library function]
-- @return [Function math library function (or any other value stored in math under that key)]
function number_meta:__index(key)
  local value = math[key]

  if value then
    return value
  else
    error('attempt to index a number value with a bad key ('..key..')', 2)
  end
end

debug.setmetatable(0, number_meta)
