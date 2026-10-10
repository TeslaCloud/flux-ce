--- Game Time gives the server an in-game clock and calendar, as opposed to the `Time`, `Date`
-- and `DateTime` classes, which deal with the real world.
-- The game calendar is the Gregorian one, with months of their usual lengths, leap years and
-- weekdays, for the years from 1 to 9999. A moment of game time is a timestamp: the number of
-- game seconds since midnight of 1 January 1970, negative for the moments before it. It has
-- no time zone. `GameTime:to_timestamp` builds one out of a date, `GameTime:get_date` takes
-- one apart, and `GameTime:parse` and `GameTime:to_string` convert between a timestamp and
-- text such as '2020-01-01 08:00'.
--
-- The server owns the clock. It starts at the date of the 'gametime_start' config, advances
-- one game minute every 'gametime_minute_length' real seconds and is saved with the rest of
-- the persistent data, so it carries on after a restart or a change of map. While the server
-- is empty and hibernates the clock stands still. With the 'gametime_real_time' config the
-- clock shows the real date and time of the server instead; the game time that was saved
-- is kept, and the clock goes back to it when the config is turned off. Staff set the clock
-- with the SetTime command, code with `GameTime:set`.
--
-- The clock is networked as the moment it was last set together with its speed, in the
-- 'gametime' networked global, and every client works the current time out by itself, so
-- nothing is sent while the clock just runs. `GameTime:now`, `GameTime:get_date` and the
-- `format` functions therefore work on the server and the client alike.
-- ```
-- -- 'Wednesday, 1 January 2020, 08:00'
-- local text = GameTime:format()
--
-- -- Close the shops for the night.
-- function MyPlugin:GameHourPassed(current, previous)
--   if current.hour == 22 then
--     self:close_shops()
--   end
-- end
-- ```
--
-- The `GameMinutePassed`, `GameHourPassed`, `GameDayPassed`, `GameMonthPassed` and
-- `GameYearPassed` hooks run on both realms as the clock rolls over, and `GameTimeSet` runs
-- when the clock is set to another moment.
--
-- Players see the time and the date in the top right corner of the tab menu. With the
-- Settings plugin loaded they can hide that clock and switch it to the 12-hour format; the
-- `ShouldDrawGameTime` hook lets a schema hide it, and the `PaintGameTimeClock` theme hook
-- lets a theme draw it.
-- @module [GameTime]

PLUGIN:set_global('GameTime')

require_relative 'cl_hooks'
require_relative 'sv_plugin'

local floor = math.floor
local format = string.format
local minute_length = 60
local hour_length = 60 * 60
local day_length = 60 * 60 * 24
local month_lengths = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local month_ids = {
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december'
}
local weekday_ids = { 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday' }

GameTime.clock_key = 'gametime'
GameTime.min_timestamp = -62135596800
GameTime.max_timestamp = 253402300799

--- Converts a date of the game calendar to the number of days between it and 1 January 1970.
-- @param year [Number year]
-- @param month [Number month, from 1 to 12]
-- @param day [Number day of the month]
-- @return [Number amount of days, negative for the dates before 1970]
local function days_from_date(year, month, day)
  if month <= 2 then
    year = year - 1
  end

  local era = floor(year / 400)
  local year_of_era = year - era * 400
  local day_of_year = floor((153 * (month > 2 and month - 3 or month + 9) + 2) / 5) + day - 1
  local day_of_era = year_of_era * 365 + floor(year_of_era / 4) - floor(year_of_era / 100) + day_of_year

  return era * 146097 + day_of_era - 719468
end

--- Converts a number of days since 1 January 1970 to a date of the game calendar.
-- @param days [Number whole amount of days, negative for the dates before 1970]
-- @return [Number year, Number month from 1 to 12, Number day of the month]
local function date_from_days(days)
  days = days + 719468

  local era = floor(days / 146097)
  local day_of_era = days - era * 146097
  local year_of_era = floor(
    (day_of_era - floor(day_of_era / 1460) + floor(day_of_era / 36524) - floor(day_of_era / 146096)) / 365
  )
  local day_of_year = day_of_era - (365 * year_of_era + floor(year_of_era / 4) - floor(year_of_era / 100))
  local month_index = floor((5 * day_of_year + 2) / 153)
  local day = day_of_year - floor((153 * month_index + 2) / 5) + 1
  local month = month_index < 10 and month_index + 3 or month_index - 9
  local year = year_of_era + era * 400

  if month <= 2 then
    year = year + 1
  end

  return year, month, day
end

--- Checks whether a value is a whole number.
-- @param value [Any]
-- @return [Boolean]
local function is_whole(value)
  return isnumber(value) and value == floor(value)
end

--- Checks whether a year of the game calendar is a leap year.
-- @param year [Number]
-- @return [Boolean]
function GameTime:is_leap_year(year)
  return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
end

--- Returns the amount of days in a month of the game calendar.
-- @param year [Number year, which decides the length of February]
-- @param month [Number month, from 1 to 12]
-- @return [Number amount of days, nil if there is no such month]
function GameTime:days_in_month(year, month)
  if month == 2 and self:is_leap_year(year) then
    return 29
  end

  return month_lengths[month]
end

--- Checks whether the numbers make up a date and a time of day that exist in the game
-- calendar: whole numbers, a year from 1 to 9999, a month from 1 to 12, a day that the month
-- has, an hour from 0 to 23 and a minute and a second from 0 to 59.
-- @param year [Number]
-- @param month [Number]
-- @param day [Number]
-- @param hour=0 [Number]
-- @param minute=0 [Number]
-- @param second=0 [Number]
-- @return [Boolean]
function GameTime:is_valid_date(year, month, day, hour, minute, second)
  hour = hour or 0
  minute = minute or 0
  second = second or 0

  if !is_whole(year) or !is_whole(month) or !is_whole(day) then return false end
  if !is_whole(hour) or !is_whole(minute) or !is_whole(second) then return false end
  if year < 1 or year > 9999 or month < 1 or month > 12 then return false end
  if day < 1 or day > self:days_in_month(year, month) then return false end

  return hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 and second >= 0 and second <= 59
end

--- Converts a date and a time of day of the game calendar to a timestamp. The numbers are
-- not checked: use `GameTime:is_valid_date` on anything that comes from a player. A day,
-- hour, minute or second past its usual range runs on into the next month, day, hour or
-- minute, which makes for simple date arithmetic; the month has to be from 1 to 12.
-- ```
-- -- Noon of 24 December 2020.
-- local timestamp = GameTime:to_timestamp(2020, 12, 24, 12)
--
-- -- Eight in the morning of the next game day, also on the last day of a month.
-- local date = GameTime:get_date()
-- local morning = GameTime:to_timestamp(date.year, date.month, date.day + 1, 8)
-- ```
-- @param year [Number year]
-- @param month=1 [Number month, from 1 to 12]
-- @param day=1 [Number day of the month]
-- @param hour=0 [Number hour, from 0 to 23]
-- @param minute=0 [Number minute, from 0 to 59]
-- @param second=0 [Number second, from 0 to 59]
-- @return [Number game seconds since midnight of 1 January 1970]
-- @see [GameTime:get_date]
function GameTime:to_timestamp(year, month, day, hour, minute, second)
  return days_from_date(year, month or 1, day or 1) * day_length
    + (hour or 0) * hour_length
    + (minute or 0) * minute_length
    + (second or 0)
end

--- Takes a timestamp apart into a date and a time of day of the game calendar.
-- ```
-- local date = GameTime:get_date()
--
-- if date.weekday >= 6 then
--   print('It is the weekend, and '..date.hour..' o\'clock.')
-- end
-- ```
-- @param timestamp=GameTime:now() [Number game seconds since midnight of 1 January 1970]
-- @return [Map the date with the fields: year, month (1 to 12), day (of the month), hour
--   (0 to 23), minute, second (whole, 0 to 59), weekday (1 for Monday to 7 for Sunday) and
--   timestamp (the timestamp that was taken apart)]
-- @see [GameTime:to_timestamp]
function GameTime:get_date(timestamp)
  timestamp = timestamp or self:now()

  local days = floor(timestamp / day_length)
  local seconds = timestamp - days * day_length
  local year, month, day = date_from_days(days)
  local hour = floor(seconds / hour_length)
  local minute = floor((seconds - hour * hour_length) / minute_length)

  return {
    year = year,
    month = month,
    day = day,
    hour = hour,
    minute = minute,
    second = floor(seconds - hour * hour_length - minute * minute_length),
    weekday = (days + 3) % 7 + 1,
    timestamp = timestamp
  }
end

--- Returns the clock as the server has networked it: the moment it was last set to and
-- how fast it runs since.
-- @return [Map the clock with the fields: base (Number timestamp the clock was set to),
--   anchor (Number CurTime() at which it was set), rate (Number game seconds that pass in a
--   real second), real (Boolean whether it follows the real time of the server) and serial
--   (Number that grows every time the clock is set to another moment); nil while the server
--   has not started the clock or the client has not received it]
function GameTime:get_clock()
  return ActiveNetwork.get_nv(self.clock_key)
end

--- Checks whether the clock is running: on the server once the saved data has been loaded,
-- on the client once the clock has arrived from the server.
-- @return [Boolean]
function GameTime:is_ready()
  return self:get_clock() != nil
end

--- Works out the timestamp that a clock shows at the moment.
-- @warning [Internal]
-- @param clock [Map clock, as returned by `GameTime:get_clock`]
-- @return [Number game seconds since midnight of 1 January 1970]
function GameTime:read_clock(clock)
  return clock.base + (CurTime() - clock.anchor) * clock.rate
end

--- Returns the current game time.
-- ```
-- -- The game time in two game hours.
-- local closing_time = GameTime:now() + 2 * 60 * 60
-- ```
-- @return [Number game seconds since midnight of 1 January 1970, with a fraction; 0 while
--   the clock is not ready]
-- @see [GameTime:get_date]
-- @see [GameTime:is_ready]
function GameTime:now()
  local clock = self:get_clock()

  if !clock then
    return 0
  end

  return self:read_clock(clock)
end

--- Returns how fast the game clock runs.
-- @return [Number game seconds that pass in a real second; 1 while the clock is not ready]
function GameTime:get_rate()
  local clock = self:get_clock()

  return clock and clock.rate or 1
end

--- Checks whether the game clock follows the real date and time of the server, which is
-- what the 'gametime_real_time' config makes it do.
-- @return [Boolean]
function GameTime:is_real_time()
  local clock = self:get_clock()

  return clock != nil and clock.real == true
end

--- Returns the current year of the game calendar.
-- @return [Number]
function GameTime:get_year()
  return self:get_date().year
end

--- Returns the current month of the game calendar.
-- @return [Number month, from 1 to 12]
function GameTime:get_month()
  return self:get_date().month
end

--- Returns the current day of the month of the game calendar.
-- @return [Number]
function GameTime:get_day()
  return self:get_date().day
end

--- Returns the current day of the week of the game calendar.
-- @return [Number 1 for Monday to 7 for Sunday]
function GameTime:get_weekday()
  return self:get_date().weekday
end

--- Returns the current hour of the game clock.
-- @return [Number hour, from 0 to 23]
function GameTime:get_hour()
  return self:get_date().hour
end

--- Returns the current minute of the game clock.
-- @return [Number minute, from 0 to 59]
function GameTime:get_minute()
  return self:get_date().minute
end

--- Returns the name of a month the way it is written in a date.
-- @param month [Number month, from 1 to 12]
-- @param lang=nil [String language code, the current language by default]
-- @return [String translated name, an empty string if there is no such month]
function GameTime:get_month_name(month, lang)
  local id = month_ids[month]

  if !id then
    return ''
  end

  local name = t('gametime.months.'..id, nil, lang)

  return name
end

--- Returns the name of a day of the week.
-- @param weekday [Number 1 for Monday to 7 for Sunday]
-- @param lang=nil [String language code, the current language by default]
-- @return [String translated name, an empty string if there is no such day]
function GameTime:get_weekday_name(weekday, lang)
  local id = weekday_ids[weekday]

  if !id then
    return ''
  end

  local name = t('gametime.weekdays.'..id, nil, lang)

  return name
end

--- Checks whether times are shown with a 12-hour clock by default. On the client that is the
-- 'gametime_twelve_hour' setting of the player, which exists when the Settings plugin is
-- loaded. The server always uses the 24-hour clock.
-- @return [Boolean]
function GameTime:uses_twelve_hour()
  if CLIENT and ClientSettings then
    return ClientSettings:get('gametime_twelve_hour', false) == true
  end

  return false
end

--- Formats the time of day of a timestamp, such as '17:05' or '5:05 PM'.
-- @param timestamp=GameTime:now() [Number game seconds since midnight of 1 January 1970]
-- @param twelve_hour=GameTime:uses_twelve_hour() [Boolean use the 12-hour clock]
-- @param lang=nil [String language code, the current language by default]
-- @return [String]
function GameTime:format_time(timestamp, twelve_hour, lang)
  local date = self:get_date(timestamp)

  if twelve_hour == nil then
    twelve_hour = self:uses_twelve_hour()
  end

  if !twelve_hour then
    return format('%02d:%02d', date.hour, date.minute)
  end

  local hour = date.hour % 12
  local period = t(date.hour < 12 and 'gametime.am' or 'gametime.pm', nil, lang)

  if hour == 0 then
    hour = 12
  end

  return format('%d:%02d %s', hour, date.minute, period)
end

--- Formats the date of a timestamp, such as 'Wednesday, 1 January 2020', or '01/01/2020' in
-- the short form. The order and the punctuation come from the language.
-- @param timestamp=GameTime:now() [Number game seconds since midnight of 1 January 1970]
-- @param short=false [Boolean write the date with numbers only]
-- @param lang=nil [String language code, the current language by default]
-- @return [String]
function GameTime:format_date(timestamp, short, lang)
  local date = self:get_date(timestamp)
  local text

  if short then
    text = t('gametime.format.date_short', {
      day = format('%02d', date.day),
      month = format('%02d', date.month),
      year = date.year
    }, lang)
  else
    text = t('gametime.format.date', {
      weekday = self:get_weekday_name(date.weekday, lang),
      day = date.day,
      month = self:get_month_name(date.month, lang),
      year = date.year
    }, lang)
  end

  return text
end

--- Formats the date and the time of day of a timestamp, such as
-- 'Wednesday, 1 January 2020, 08:00'.
-- @param timestamp=GameTime:now() [Number game seconds since midnight of 1 January 1970]
-- @param twelve_hour=GameTime:uses_twelve_hour() [Boolean use the 12-hour clock]
-- @param lang=nil [String language code, the current language by default]
-- @return [String]
-- @see [GameTime:format_date]
-- @see [GameTime:format_time]
function GameTime:format(timestamp, twelve_hour, lang)
  timestamp = timestamp or self:now()

  local text = t('gametime.format.date_time', {
    date = self:format_date(timestamp, false, lang),
    time = self:format_time(timestamp, twelve_hour, lang)
  }, lang)

  return text
end

--- Writes a timestamp as 'YYYY-MM-DD HH:MM', which reads the same in every language and is
-- what `GameTime:parse` takes.
-- @param timestamp=GameTime:now() [Number game seconds since midnight of 1 January 1970]
-- @return [String]
function GameTime:to_string(timestamp)
  local date = self:get_date(timestamp)

  return format('%04d-%02d-%02d %02d:%02d', date.year, date.month, date.day, date.hour, date.minute)
end

--- Reads a timestamp from text: a date as 'YYYY-MM-DD', a time of day as 'HH:MM' or
-- 'HH:MM:SS', or a date followed by a time of day. What the text leaves out is taken from
-- another moment: a date alone keeps its hour and minute, a time of day alone its date.
-- ```
-- GameTime:parse('2020-01-01 08:00')
-- -- Half past nine in the evening of the current game day.
-- GameTime:parse('21:30')
-- -- The same time of day as now, on another date.
-- GameTime:parse('2021-06-15')
-- ```
-- @param text [String text to read]
-- @param relative_to=GameTime:now() [Number timestamp that fills in what the text leaves out]
-- @return [Number game seconds since midnight of 1 January 1970, or nil if the text is not
--   a date or a time that exists in the game calendar]
-- @see [GameTime:to_string]
function GameTime:parse(text, relative_to)
  if !isstring(text) then return end

  text = text:strip()

  local base = self:get_date(relative_to)
  local year, month, day = base.year, base.month, base.day
  local hour, minute, second = base.hour, base.minute, 0
  local date_year, date_month, date_day, rest = text:match('^(%d+)%-(%d%d?)%-(%d%d?)(.*)$')

  if date_year then
    year, month, day = tonumber(date_year), tonumber(date_month), tonumber(date_day)
    text = rest:strip()
  elseif text == '' then
    return
  end

  if text != '' then
    local time_hour, time_minute, time_second = text:match('^(%d%d?):(%d%d)$')

    if !time_hour then
      time_hour, time_minute, time_second = text:match('^(%d%d?):(%d%d):(%d%d)$')
    end

    if !time_hour then return end

    hour, minute, second = tonumber(time_hour), tonumber(time_minute), tonumber(time_second) or 0
  end

  if !self:is_valid_date(year, month, day, hour, minute, second) then return end

  return self:to_timestamp(year, month, day, hour, minute, second)
end

--- Compares the game time with the last minute that was seen and runs the hooks of the
-- minute, hour, day, month and year that have begun since. Every hook runs once per check,
-- no matter how much game time has gone by, and only as the clock moves forward: setting it
-- to another moment runs `GameTimeSet` instead. The client starts checking once the local
-- player has been initialized.
-- @warning [Internal]
function GameTime:check_rollover()
  local clock = self:get_clock()

  if !clock then return end
  if CLIENT and (!IsValid(PLAYER) or !PLAYER:has_initialized()) then return end

  local minute = floor(self:read_clock(clock) / minute_length)
  local last_minute = self.last_minute

  if !last_minute then
    self.last_minute = minute

    return
  end

  if minute <= last_minute then return end

  self.last_minute = minute

  local current = self:get_date(minute * minute_length)
  local previous = self:get_date(last_minute * minute_length)

  --- Called on the server and the client when a new minute of the game clock has begun.
  -- The clock is checked eight times a second, and the hook runs once per check even if
  -- several game minutes have gone by since the last one, which happens when a game minute
  -- is shorter than that or when the clock follows the real time and the server has been
  -- hibernating. Not called when the clock is set to another moment: see `GameTimeSet`.
  -- @param current [Map The date at the start of the minute that has begun, as returned by
  --   `GameTime:get_date`]
  -- @param previous [Map The date at the start of the minute the clock was in at the
  --   previous check]
  hook.Run('GameMinutePassed', current, previous)

  if floor(minute / 60) != floor(last_minute / 60) then
    --- Called on the server and the client when a new hour of the game clock has begun,
    -- after `GameMinutePassed`. Runs once even if several game hours have gone by since the
    -- previous check of the clock. Not called when the clock is set to another moment.
    -- @param current [Map The date at the start of the minute that has begun, as returned by
    --   `GameTime:get_date`; its minute is 0 unless more than an hour has gone by at once]
    -- @param previous [Map The date at the start of the minute the clock was in at the
    --   previous check]
    hook.Run('GameHourPassed', current, previous)
  end

  if floor(minute / 1440) != floor(last_minute / 1440) then
    --- Called on the server and the client when a new day of the game calendar has begun,
    -- after `GameHourPassed`. Runs once even if several game days have gone by since the
    -- previous check of the clock. Not called when the clock is set to another moment.
    -- @param current [Map The date at the start of the minute that has begun, as returned by
    --   `GameTime:get_date`]
    -- @param previous [Map The date at the start of the minute the clock was in at the
    --   previous check]
    hook.Run('GameDayPassed', current, previous)
  end

  if current.month != previous.month or current.year != previous.year then
    --- Called on the server and the client when a new month of the game calendar has begun,
    -- after `GameDayPassed`. Runs once even if several game months have gone by since the
    -- previous check of the clock. Not called when the clock is set to another moment.
    -- @param current [Map The date at the start of the minute that has begun, as returned by
    --   `GameTime:get_date`]
    -- @param previous [Map The date at the start of the minute the clock was in at the
    --   previous check]
    hook.Run('GameMonthPassed', current, previous)
  end

  if current.year != previous.year then
    --- Called on the server and the client when a new year of the game calendar has begun,
    -- after `GameMonthPassed`. Runs once even if several game years have gone by since the
    -- previous check of the clock. Not called when the clock is set to another moment.
    -- @param current [Map The date at the start of the minute that has begun, as returned by
    --   `GameTime:get_date`]
    -- @param previous [Map The date at the start of the minute the clock was in at the
    --   previous check]
    hook.Run('GameYearPassed', current, previous)
  end
end

--- Checks eight times a second whether the game clock has rolled over.
function GameTime:LazyTick()
  self:check_rollover()
end
