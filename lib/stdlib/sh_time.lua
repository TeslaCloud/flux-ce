--- Time intervals: the `Time` class, its constructors for every unit of time and its
-- human-readable formatting.
-- The constructors are also installed into the `math` library, so that an interval can be
-- written as `math.minutes(5)` and added to or subtracted from a `Date` or a `DateTime`.

--- The Time class represents a time interval, not a point in time.
-- For points in time, please use Date or DateTime.
-- @see [Date]
-- @see [DateTime]
class 'Time'

local ms_const      = 0.001
local m_const       = 60
local h_const       = 60 * 60
local d_const       = 60 * 60 * 24
local w_const       = 60 * 60 * 24 * 7
local mt_const      = 60 * 60 * 24 * 30
local y_const       = 60 * 60 * 24 * 365
local ms_const_d    = 1 / ms_const
local m_const_d     = 1 / m_const
local h_const_d     = 1 / h_const
local d_const_d     = 1 / d_const
local w_const_d     = 1 / w_const
local mt_const_d    = 1 / mt_const
local y_const_d     = 1 / y_const

local mappings      = {
  ['milliseconds']  = ms_const_d,
  ['millisecond']   = ms_const_d,
  ['ms']            = ms_const_d,
  ['seconds']       = 1,
  ['second']        = 1,
  ['s']             = 1,
  ['minutes']       = m_const_d,
  ['minute']        = m_const_d,
  ['m']             = m_const_d,
  ['hours']         = h_const_d,
  ['hour']          = h_const_d,
  ['h']             = h_const_d,
  ['days']          = d_const_d,
  ['day']           = d_const_d,
  ['d']             = d_const_d,
  ['weeks']         = w_const_d,
  ['week']          = w_const_d,
  ['w']             = w_const_d,
  ['months']        = mt_const_d,
  ['month']         = mt_const_d,
  ['mo']            = mt_const_d,
  ['years']         = y_const_d,
  ['year']          = y_const_d,
  ['y']             = y_const_d
}

--- Initializes a new Time object that represents a time interval.
-- ```
-- local two_days = Time:days(2)
-- local a_day_after_tomorrow = Date:now() + two_days
-- ```
-- @param seconds=current time [Number UNIX time]
function Time:init(seconds)
  self.time = seconds or os.time()

  for k, v in pairs(mappings) do
    self[k] = function(this)
      return this.time * v
    end
  end
end

--- Creates a Time object representing a certain amount of milliseconds.
-- @param n [Number amount of milliseconds]
-- @return [Time]
function Time:milliseconds(n)
  return Time.new(n * ms_const)
end

--- Creates a Time object representing a certain amount of seconds.
-- @param n [Number amount of seconds]
-- @return [Time]
function Time:seconds(n)
  return Time.new(n)
end

--- Creates a Time object representing a certain amount of minutes.
-- @param n [Number amount of minutes]
-- @return [Time]
function Time:minutes(n)
  return Time.new(n * m_const)
end

--- Creates a Time object representing a certain amount of hours.
-- @param n [Number amount of hours]
-- @return [Time]
function Time:hours(n)
  return Time.new(n * h_const)
end

--- Creates a Time object representing a certain amount of days.
-- @param n [Number amount of days]
-- @return [Time]
function Time:days(n)
  return Time.new(n * d_const)
end

--- Creates a Time object representing a certain amount of weeks.
-- @param n [Number amount of weeks]
-- @return [Time]
function Time:weeks(n)
  return Time.new(n * w_const)
end

--- Creates a Time object representing a certain amount of months.
-- @param n [Number amount of months]
-- @return [Time]
function Time:months(n)
  return Time.new(n * mt_const)
end

--- Creates a Time object representing a certain amount of years.
-- @param n [Number amount of years]
-- @return [Time]
function Time:years(n)
  return Time.new(n * y_const)
end

--- @ignore
Time.millisecond  = Time.milliseconds
Time.ms           = Time.milliseconds
Time.minute       = Time.minutes
Time.hour         = Time.hours
Time.day          = Time.days
Time.week         = Time.weeks
Time.month        = Time.months
Time.year         = Time.years

--- Install Time shortcuts into the math library.
local function installable(func)
  return function(n)
    return func(Time, n)
  end
end

math.milliseconds = installable(Time.milliseconds)
math.millisecond  = installable(Time.milliseconds)
math.ms           = installable(Time.milliseconds)
math.seconds      = installable(Time.seconds)
math.second       = installable(Time.seconds)
math.minutes      = installable(Time.minutes)
math.minute       = installable(Time.minutes)
math.hours        = installable(Time.hours)
math.hour         = installable(Time.hours)
math.days         = installable(Time.days)
math.day          = installable(Time.days)
math.weeks        = installable(Time.weeks)
math.week         = installable(Time.weeks)
math.months       = installable(Time.months)
math.month        = installable(Time.months)
math.years        = installable(Time.years)
math.year         = installable(Time.years)

--- Creates a nice string representation of time.
-- @param time=self.time [Number]
-- @return [String time phrase, String 'time.from_now' or 'time.ago' phrase (empty for
--   'time.just_now'), Number amount of time in the unit of the phrase]
-- @see [Time#format_nice]
function Time:nice(time)
  time = time or self.time or 0
  local seconds = math.abs(time or self.time)
  local minutes = seconds * m_const_d
  local hours   = seconds * h_const_d
  local days    = seconds * d_const_d
  local months  = seconds * mt_const_d
  local weeks   = seconds * w_const_d
  local years   = seconds * y_const_d

  local time_data =
    seconds < 15  and { 'just_now', seconds } or
    seconds < 45  and { 'seconds', seconds }  or
    seconds < 90  and { 'minute', minutes }   or
    minutes < 45  and { 'minutes', minutes }  or
    minutes < 90  and { 'hour', hours }       or
    hours   < 24  and { 'hours', hours }      or
    hours   < 42  and { 'day', days }         or
    days    < 7   and { 'days', days }        or
    weeks   < 1.5 and { 'week', weeks }       or
    days    < 31  and { 'weeks', weeks }      or
    days    < 45  and { 'month', months }     or
    days    < 365 and { 'months', months }    or
    years   < 1.5 and { 'year', years }       or
                      { 'years', years }

  return 'time.'..time_data[1], time_data[1] != 'just_now'
         and (time >= 0 and 'time.from_now' or 'time.ago')
         or '', time_data[2]
end

--- Creates a nice string representation of a point in time relative to now.
-- @param time=current time [Number/Date UNIX time, or a Date or DateTime object]
-- @return [String time phrase, String 'time.from_now' for a time in the future or 'time.ago'
--   for one in the past (empty for 'time.just_now'), Number amount of time in the unit of
--   the phrase]
-- @see [Time#nice]
function Time:nice_from_now(time)
  if istable(time) then
    time = time.time
  end

  local diff = Time.new(DateTime:at(time).time - DateTime:now().time)

  return diff:nice()
end

--- Same as nice, but performs formatting.
-- Takes the three values that nice returns and translates them into readable text. The
-- amount is rounded down, with 'about' or 'over' in front of it if anything was cut off, and
-- is never shown as less than 1.
-- ```
-- local text = Time:format_nice(Time:minutes(5):nice()) -- e.g. '5 minutes from now'
-- ```
-- @param suffix [String time phrase, as returned by nice]
-- @param from_now [String 'time.from_now' or 'time.ago' phrase or an empty string, as
--   returned by nice]
-- @param amt [Number amount of time, as returned by nice]
-- @param lang=current language [String language to translate to]
-- @return [String phrases]
function Time:format_nice(suffix, from_now, amt, lang)
  if suffix != 'time.just_now' then
    local floored = math.max(math.floor(amt or 1), 1)
    local dec = amt - floored
    local dec_prefix

    if dec > 0 then
      dec_prefix = t(dec > 0.6 and 'time.over' or 'time.about', nil, lang)
    end

    return (dec_prefix and dec_prefix..' ' or '')..
           tostring(floored)..' '..
           t(suffix, nil, lang)..
           (from_now != '' and ' '..t(from_now, nil, lang) or '')
  else
    return t(suffix, nil, lang)
  end
end

--- Formats date-time using a format string.
-- @param fmt [String DateTime format]
-- @param time=self.time [Number UNIX time]
-- @return [String formatted string]
-- @see [Date#strftime]
function Time:strftime(fmt, time)
  return Date.strftime(self or Time, fmt, time)
end

--- Returns the current date-time.
-- @return [DateTime present time]
-- @see [DateTime#now]
function Time:now()
  return DateTime:now()
end

--- Returns the following day's date.
-- @return [Date tomorrow]
-- @see [DateTime#tomorrow]
function Time:tomorrow()
  return DateTime:tomorrow()
end

--- Returns the previous day's date.
-- @return [Date yesterday]
-- @see [DateTime#yesterday]
function Time:yesterday()
  return DateTime:yesterday()
end
