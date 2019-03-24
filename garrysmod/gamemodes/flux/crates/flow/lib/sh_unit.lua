--- A class to convert conventional metrics to Source Engine units.
class 'Unit'

local inches_in_cm = 1 / 2.54
local inches_in_mm = inches_in_cm * 0.1

--- Converts a number of inches to Source Engine units.
-- Since Source Engine units are actually inches, we just return the value as-is.
-- @return[Number]
function Unit:inch(n)
  return n
end

--- Converts a number of millimeters to Source Engine units.
-- @return[Number]
function Unit:millimeter(n)
  return n * inches_in_cm
end

--- Converts a number of centimeters to Source Engine units.
-- @return[Number]
function Unit:centimeter(n)
  return n * inches_in_cm
end

--- Converts a number of meters to Source Engine units.
-- @return[Number]
function Unit:meter(n)
  return self:centimeter(n * 100)
end

--- Converts a number of kilometers to Source Engine units.
-- @return[Number]
function Unit:kilometer(n)
  return self:meter(n * 1000)
end

--- Converts a number of feet to Source Engine units.
-- @return[Number]
function Unit:foot(n)
  return n * 12
end

--- Converts a number of yards to Source Engine units.
-- @return[Number]
function Unit:yard(n)
  return self:foot(n * 3)
end

--- Converts a number of miles to Source Engine units.
-- @return[Number]
function Unit:mile(n)
  return self:foot(n * 5280)
end

--- Converts the amount of driving hours at 100 km/h average speed to
-- Source Engine units.
-- @return[Number]
function Unit:time_to_drive_there(n)
  return self:kilometer(n * 100)
end

-- Aliases for convenience.
Unit.inches       = Unit.inch
Unit.unit         = Unit.inch
Unit.units        = Unit.inch
Unit.millimeters  = Unit.millimeter
Unit.mm           = Unit.millimeter
Unit.meters       = Unit.meter
Unit.m            = Unit.meter
Unit.kilometers   = Unit.kilometer
Unit.km           = Unit.kilometer
Unit.feet         = Unit.foot
Unit.ft           = Unit.foot
Unit.yards        = Unit.yard
Unit.yd           = Unit.yard
Unit.miles        = Unit.mile
Unit.mi           = Unit.mile
