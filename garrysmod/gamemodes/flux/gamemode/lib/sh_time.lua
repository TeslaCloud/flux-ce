class 'Time'

local ms_const    = 0.001
local m_const     = 60
local h_const     = 60 * 60
local d_const     = 60 * 60 * 24
local w_const     = 60 * 60 * 24 * 7
local mt_const    = 60 * 60 * 24 * 30
local y_const     = 60 * 60 * 24 * 365
local ms_const_d  = 1 / ms_const
local m_const_d   = 1 / m_const
local h_const_d   = 1 / h_const
local d_const_d   = 1 / d_const
local w_const_d   = 1 / w_const
local mt_const_d  = 1 / mt_const
local y_const_d   = 1 / y_const

local mappings = {
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

function Time:init(year, month, day, hour, minute, second, timezone)
  self.time = os.time {
    year = year,
    month = month,
    day = day,
    hour = hour,
    min = minute,
    sec = second
  }

  self.timezone = timezone or Time:zone()

  for k, v in pairs(mappings) do
    self[k] = function(this)
      return this.time * v
    end
  end
end

function Time:at(seconds, timezone)
  local date = os.date('*t', seconds)
  return Time.new(date.year, date.month, date.day, date.hour, date.min, date.sec, timezone)
end

function Time:utc(time)
  local date = os.date('!*t', time or self.time)
  return Time.new(date.year, date.month, date.day, date.hour, date.min, date.sec, timezone)
end

function Time:now()
  return Time:at(os.time())
end

function Time:tomorrow()
  return Time:now() + Time:days(1)
end

function Time:yesterday()
  return Time:now() - Time:days(1)
end

function Time:zone()
  return os.date('%z', self.time)
end

function Time:milliseconds(n)
  return Time:at(n * ms_const)
end

function Time:seconds(n)
  return Time:at(n)
end

function Time:minutes(n)
  return Time:at(n * m_const)
end

function Time:hours(n)
  return Time:at(n * h_const)
end

function Time:days(n)
  return Time:at(n * d_const)
end

function Time:weeks(n)
  return Time:at(n * w_const)
end

function Time:months(n)
  return Time:at(n * mt_const)
end

function Time:years(n)
  return Time:at(n * y_const)
end

Time.millisecond  = Time.milliseconds
Time.ms           = Time.milliseconds
Time.minute       = Time.minutes
Time.hour         = Time.hours
Time.day          = Time.days
Time.week         = Time.weeks
Time.month        = Time.months
Time.year         = Time.years

function Time:strftime(fmt, time)
  return os.date(fmt, time or self.time)
end

function Time:nice(time)
  time = time or self.time
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
    days    < 6   and { 'days', days }        or
    hours   < 7   and { 'week', weeks }       or
    days    < 31  and { 'weeks', weeks }      or
    days    < 45  and { 'month', months }     or
    days    < 365 and { 'months', months }    or
    years   < 1.5 and { 'year', years }       or
                      { 'years', years }

  return 'time.'..time_data[1], time_data[1] != 'just_now' and (time >= 0 and 'time.from_now' or 'time.ago') or '', time_data[2]
end

function Time:nice_from_now(time)
  local now = Time:now()
  local diff = (istable(time) and time or Time:at(time)) - now
  return diff:nice()
end

function Time:format_nice(suffix, from_now, amt, lang)
  if suffix != 'time.just_now' then
    local floored = math.floor(amt or 1)
    local dec = amt - floored
    local dec_prefix

    if dec > 0 then
      dec_prefix = t(dec > 0.6 and 'time.over' or 'time.about', nil, lang)
    end

    return (dec_prefix and dec_prefix..' ' or '')..tostring(floored)..' '..t(suffix, nil, lang)..(from_now != '' and ' '..t(from_now, nil, lang) or '')
  else
    return t(suffix, nil, lang)
  end
end

function Time:iso(time)
  return self:strftime('%Y-%m-%d %H:%M:%S', time or self.time)
end

local function run_if_valid_time(right, callback)
  if istable(right) and right.class_name == Time.class_name then
    return callback(right)
  end
end

function Time:__add(right)
  return run_if_valid_time(right, function(right)
    return Time:at(self.time + right.time)
  end)
end

function Time:__sub(right)
  return run_if_valid_time(right, function(right)
    return Time:at(self.time - right.time)
  end)
end

function Time:__mul(right)
  return run_if_valid_time(right, function(right)
    return Time:at(self.time * right.time)
  end)
end

function Time:__div(right)
  return run_if_valid_time(right, function(right)
    return Time:at(self.time / right.time)
  end)
end

function Time:__concat(right)
  return run_if_valid_time(right, function(right)
    return Time:at(self.time + right.time)
  end)
end

function Time:__tostring()
  return self:iso()
end
