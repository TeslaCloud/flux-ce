--- A class to convert conventional metrics to Source Engine units.
class 'Unit'

-- Constants for faster convertion.
local inches_in_cm = 1 / 2.54
local inches_in_mm = inches_in_cm * 0.1
local inches_in_ft = 1 / 12
local feet_in_yd = 1 / 3
local feet_in_mi = 1 / 5280

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

--- Converts the amount of Source Engine units to centimeters.
-- @return[Number]
function Unit:to_centimeters(n)
  return n * 2.54
end

--- Converts the amount of Source Engine units to meters.
-- @return[Number]
function Unit:to_meters(n)
  return self:to_centimeters(n) * 0.01
end

--- Converts the amount of Source Engine units to millimeters.
-- @return[Number]
function Unit:to_millimeters(n)
  return self:to_centimeters(n) * 10
end

--- Converts the amount of Source Engine units to kilometers.
-- @return[Number]
function Unit:to_kilometers(n)
  return self:to_meters(n) * 0.001
end

--- Converts the amount of Source Engine units to inches.
-- @return[Number]
function Unit:to_inches(n)
  return n
end

--- Converts the amount of Source Engine units to feet.
-- @return[Number]
function Unit:to_feet(n)
  return n * inches_in_ft
end

--- Converts the amount of Source Engine units to yards.
-- @return[Number]
function Unit:to_yards(n)
  return self:to_feet(n) * feet_in_yd
end

--- Converts the amount of Source Engine units to miles.
-- @return[Number]
function Unit:to_miles(n)
  return self:to_feet(n) * feet_in_mi
end

-- Aliases for convenience.
Unit.inches         = Unit.inch
Unit.unit           = Unit.inch
Unit.units          = Unit.inch
Unit.millimeters    = Unit.millimeter
Unit.mm             = Unit.millimeter
Unit.centimeters    = Unit.centimeter
Unit.cm             = Unit.centimeter
Unit.meters         = Unit.meter
Unit.m              = Unit.meter
Unit.kilometers     = Unit.kilometer
Unit.km             = Unit.kilometer
Unit.feet           = Unit.foot
Unit.ft             = Unit.foot
Unit.yards          = Unit.yard
Unit.yd             = Unit.yard
Unit.miles          = Unit.mile
Unit.mi             = Unit.mile
Unit.to_foot        = Unit.to_feet
Unit.to_ft          = Unit.to_feet
Unit.to_yard        = Unit.to_yards
Unit.to_yd          = Unit.to_yards
Unit.to_mile        = Unit.to_miles
Unit.to_mi          = Unit.to_miles
Unit.to_meter       = Unit.to_meters
Unit.to_m           = Unit.to_meters
Unit.to_millimeter  = Unit.to_millimeters
Unit.to_mm          = Unit.to_millimeters
Unit.to_centimeter  = Unit.to_centimeters
Unit.to_cm          = Unit.to_centimeters
Unit.to_kilometer   = Unit.to_kilometers
Unit.to_km          = Unit.to_kilometers
