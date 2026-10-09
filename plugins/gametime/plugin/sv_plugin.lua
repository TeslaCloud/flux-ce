--- Server side of the Game Time plugin: starts the game clock from the saved time or from
-- the 'gametime_start' config, networks it, keeps it on the real time of the server when
-- the 'gametime_real_time' config asks for that, follows the changes of its configs, sets it
-- on request and saves it.
-- The game time is saved for the schema as a whole rather than for every map, so that the
-- calendar carries on when the map changes.

local default_start = '2020-01-01 08:00'
local default_minute_length = 60
local real_time_tolerance = 2

--- Returns the key of the data file that the game time of the current schema is saved in.
-- @return [String key for `Data.save` and `Data.load`]
local function data_key()
  return 'schemas/'..Flux.get_schema_folder()..'/gametime'
end

--- Converts the length of a game minute to the speed of the game clock.
-- @param minute_length [Number real seconds a game minute lasts, as set in the
--   'gametime_minute_length' config]
-- @return [Number game seconds that pass in a real second]
local function to_rate(minute_length)
  return 60 / math.max(tonumber(minute_length) or default_minute_length, 0.01)
end

--- Returns the moment the game clock starts from when no game time has been saved: the
-- 'gametime_start' config, or 08:00 of 1 January 2020 if the config cannot be read as a date.
-- @return [Number game seconds since midnight of 1 January 1970]
function GameTime:get_start()
  local start = Config.get('gametime_start', default_start)
  local timestamp = self:parse(start, 0)

  if !timestamp then
    ErrorNoHalt(
      "[GameTime] The 'gametime_start' config ('"..tostring(start).."') is not a date written as "..
      "'YYYY-MM-DD HH:MM'! Starting the game clock at "..default_start..' instead.\n'
    )

    timestamp = self:parse(default_start, 0)
  end

  return timestamp
end

--- Returns the real date and time of the server, in its own time zone, as a timestamp of
-- the game calendar.
-- @return [Number game seconds since midnight of 1 January 1970]
function GameTime:get_real_timestamp()
  local real = os.date('*t')

  return self:to_timestamp(real.year, real.month, real.day, real.hour, real.min, real.sec)
end

--- Puts the clock at a timestamp from this moment on and networks it to everyone. A jump
-- makes the rollover hooks start over from the new time and runs `GameTimeSet`; without it
-- the hooks carry on as if the clock had simply run on.
-- @warning [Internal]
-- @param timestamp [Number game seconds since midnight of 1 January 1970 that the clock
--   shows from now on]
-- @param rate [Number game seconds that pass in a real second]
-- @param real_time [Boolean whether the clock follows the real time of the server]
-- @param is_jump=false [Boolean the clock is being set to another moment, as opposed to
--   being started, changing its speed or being corrected]
function GameTime:set_clock(timestamp, rate, real_time, is_jump)
  local clock = self:get_clock()
  local old_timestamp = clock and self:read_clock(clock)
  local serial = clock and clock.serial or 0

  if is_jump and clock then
    serial = serial + 1
  end

  ActiveNetwork.set_nv(self.clock_key, {
    base = timestamp,
    anchor = CurTime(),
    rate = rate,
    real = real_time and true or false,
    serial = serial
  })

  if is_jump or !clock then
    self.last_minute = math.floor(timestamp / 60)
  end

  if is_jump and clock then
    --- Called on the server and the client when the game clock has been set to another
    -- moment: by the SetTime command or `GameTime:set`, when the 'gametime_real_time' config
    -- is turned on or off, or when the real time that the clock follows goes back, as it
    -- does at the end of daylight saving time. The clock already shows the new time. The
    -- rollover hooks (`GameMinutePassed` and the others) are not run for the time that was
    -- skipped; they carry on from the new time.
    -- @param timestamp [Number The game time the clock has been set to, in game seconds
    --   since midnight of 1 January 1970]
    -- @param old_timestamp [Number The game time the clock showed before it was set]
    hook.Run('GameTimeSet', timestamp, old_timestamp)
  end
end

--- Sets the game clock and saves the new time. Refused while the clock follows the real
-- time of the server.
-- ```
-- -- Skip to the next morning.
-- local date = GameTime:get_date()
--
-- GameTime:set(GameTime:to_timestamp(date.year, date.month, date.day + 1, 8))
--
-- -- Set the clock from text.
-- local timestamp = GameTime:parse('2020-01-01 08:00')
--
-- if timestamp then
--   GameTime:set(timestamp)
-- end
-- ```
-- @param timestamp [Number game seconds since midnight of 1 January 1970, within the years
--   from 1 to 9999]
-- @return [Boolean whether the clock has been set, String language phrase of the error if
--   it has not: 'error.gametime.not_ready', 'error.gametime.real_time' or
--   'error.gametime.invalid']
-- @see [GameTime:to_timestamp]
-- @see [GameTime:parse]
function GameTime:set(timestamp)
  local clock = self:get_clock()

  if !clock then
    return false, 'error.gametime.not_ready'
  end

  if clock.real then
    return false, 'error.gametime.real_time'
  end

  if !isnumber(timestamp) or !(timestamp >= self.min_timestamp and timestamp <= self.max_timestamp) then
    return false, 'error.gametime.invalid'
  end

  self:set_clock(timestamp, clock.rate, false, true)
  self:save()

  return true
end

--- Writes the current game time to the data of the schema, as a date and a time of day.
-- Nothing is written while the clock follows the real time of the server, so the game time
-- that was saved before stays there for when the 'gametime_real_time' config is turned off
-- again.
function GameTime:save()
  local clock = self:get_clock()

  if !clock or clock.real then return end

  local date = self:get_date()

  Data.save(data_key(), {
    year = date.year,
    month = date.month,
    day = date.day,
    hour = date.hour,
    minute = date.minute,
    second = date.second
  })
end

--- Reads the game time that `GameTime:save` has written for the schema.
-- @return [Number game seconds since midnight of 1 January 1970, or nil if nothing has been
--   saved yet or the saved date cannot be read]
function GameTime:load()
  local saved = Data.load(data_key(), {})

  if !istable(saved) then return end

  local year, month, day = saved.year, saved.month, saved.day
  local hour, minute, second = saved.hour, saved.minute, saved.second

  if !self:is_valid_date(year, month, day, hour, minute, second) then return end

  return self:to_timestamp(year, month, day, hour, minute, second)
end

--- Starts the game clock when the persistent data is loaded: at the real time of the server
-- with the 'gametime_real_time' config, otherwise at the time that was saved, or at the
-- 'gametime_start' config if nothing has been saved yet.
function GameTime:LoadData()
  if Config.get('gametime_real_time') == true then
    self:set_clock(self:get_real_timestamp(), 1, true)

    return
  end

  local timestamp = self:load() or self:get_start()

  self:set_clock(timestamp, to_rate(Config.get('gametime_minute_length')), false)
end

--- Saves the game time with the rest of the persistent data.
function GameTime:SaveData()
  self:save()
end

--- Applies the changes of the 'gametime_minute_length' and 'gametime_real_time' configs to
-- the running clock. A new minute length changes the speed from the current moment on.
-- Turning the real time on saves the game time and moves the clock to the real time of the
-- server. Turning it off moves the clock back to the game time that was saved, the same
-- moment it would start from after a restart, or to the 'gametime_start' config if nothing
-- has been saved. Both count as setting the clock and run `GameTimeSet`. The new value is
-- compared with the running clock rather than with the old value of the config, because a
-- code refresh puts the configs back to their defaults without telling the plugin.
-- @param key [String config key]
-- @param old_value [Any value the config had]
-- @param new_value [Any value the config is about to get]
function GameTime:OnConfigSet(key, old_value, new_value)
  local clock = self:get_clock()

  if !clock then return end

  if key == 'gametime_minute_length' then
    local rate = to_rate(new_value)

    if !clock.real and rate != clock.rate then
      self:set_clock(self:read_clock(clock), rate, false)
    end
  elseif key == 'gametime_real_time' then
    if new_value == true and !clock.real then
      self:save()
      self:set_clock(self:get_real_timestamp(), 1, true, true)
    elseif new_value != true and clock.real then
      local timestamp = self:load() or self:get_start()

      self:set_clock(timestamp, to_rate(Config.get('gametime_minute_length')), false, true)
    end
  end
end

--- Keeps a clock that follows the real time of the server on that time, by correcting it
-- once it is two seconds or more away. That happens when the server has been hibernating
-- or when its own clock has been changed. A correction that takes the clock back by more
-- than a minute counts as setting it, so that the rollover hooks start over.
function GameTime:OneSecond()
  local clock = self:get_clock()

  if !clock or !clock.real then return end

  local real = self:get_real_timestamp()
  local drift = real - self:read_clock(clock)

  if math.abs(drift) < real_time_tolerance then return end

  self:set_clock(real, 1, true, drift < -60)
end
