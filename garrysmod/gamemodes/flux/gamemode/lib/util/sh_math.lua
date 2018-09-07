do
  local hex_digits = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}

  -- A function to convert a single hexadecimal digit to decimal.
  function util.hex_to_decimal(hex)
    if isnumber(hex) then
      return hex
    end

    hex = hex:lower()

    local negative = false

    if hex:starts("-") then
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

-- A function to convert hexadecimal number to decimal.
function util.hex_to_decimalimal(hex)
  if isnumber(hex) then return hex end

  local sum = 0
  local chars = table.Reverse(string.Explode("", hex))
  local idx = 1

  for i = 0, hex:len() - 1 do
    sum = sum + util.hex_to_decimal(chars[idx]) * math.pow(16, i)
    idx = idx + 1
  end

  return sum
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

  if d1 > 0 and d2 > 0 then return false end
  if d1 < 0 and d2 < 0 then return false end

  a2 = vTo2.y - vFrom2.y
  b2 = vFrom2.x - vTo2.x
  c2 = (vTo2.x * vFrom2.y) - (vFrom2.x * vTo2.y)

  d1 = (a2 * vFrom.x) + (b2 * vFrom.y) + c2
  d2 = (a2 * vTo.x) + (b2 * vTo.y) + c2

  if d1 > 0 and d2 > 0 then return false end
  if d1 < 0 and d2 < 0 then return false end

  -- Vectors are collinear or intersect.
  -- No need for further checks.
  return true
end

-- A function to determine whether a 2D point is inside of a 2D polygon.
function util.vector_in_poly(point, polyVertices)
  if !isvector(point) or !istable(polyVertices) or !isvector(polyVertices[1]) then
    return
  end

  local intersections = 0

  for k, v in ipairs(polyVertices) do
    local nextVert

    if k < #polyVertices then
      nextVert = polyVertices[k + 1]
    elseif k == #polyVertices then
      nextVert = polyVertices[1]
    end

    if nextVert and util.vectors_intersect(point, Vector(99999, 99999, 0), v, nextVert) then
      intersections = intersections + 1
    end
  end

  -- Check whether number of intersections is even or odd.
  -- If it's odd then the point is inside the polygon.
  if intersections % 2 == 0 then
    return false
  else
    return true
  end
end
