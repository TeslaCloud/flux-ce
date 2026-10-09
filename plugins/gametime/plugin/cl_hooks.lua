--- Client side of the Game Time plugin: registers the settings of the clock, notices when the
-- server sets the game clock to another moment and puts the clock into the tab menu.

--- Registers the settings of the clock with the Settings plugin: 'gametime_clock', which
-- shows or hides the clock of the tab menu, and 'gametime_twelve_hour', which switches the
-- game time to the 12-hour format. Only called when the Settings plugin is loaded.
function GameTime:RegisterClientSettings()
  ClientSettings:register_setting('gametime_clock', {
    type = 'boolean',
    default = true,
    category = 'settings.categories.interface',
    name = 'settings.gametime.clock.name',
    description = 'settings.gametime.clock.desc'
  })

  ClientSettings:register_setting('gametime_twelve_hour', {
    type = 'boolean',
    default = false,
    category = 'settings.categories.interface',
    name = 'settings.gametime.twelve_hour.name',
    description = 'settings.gametime.twelve_hour.desc'
  })
end

--- Checks whether the clock of the tab menu should be drawn: the game clock has arrived from
-- the server, the player has not turned the 'gametime_clock' setting off and the
-- `ShouldDrawGameTime` hook does not object.
-- @return [Boolean]
function GameTime:should_draw_clock()
  if !self:is_ready() then
    return false
  end

  if ClientSettings and ClientSettings:get('gametime_clock', true) == false then
    return false
  end

  --- Asks whether the game date and time may be shown to the local player. Called on the
  -- client every frame while the tab menu is open, before its clock is drawn. A schema can
  -- use it to keep the time from characters that have no way of knowing it.
  -- @return [Boolean Return false to hide the clock]
  return hook.Run('ShouldDrawGameTime') != false
end

--- Notices that the server has set the game clock to another moment, which is when the
-- serial of the networked clock changes: makes the rollover hooks start over from the new
-- time and runs `GameTimeSet`. A clock that arrives for the first time, changes its speed or
-- is corrected keeps its serial.
-- @param key [String name of the networked global that has changed]
-- @param old_value [Any previous value, the previous clock in the case of the game clock]
-- @param new_value [Any new value, the new clock in the case of the game clock]
function GameTime:GlobalNetVarChanged(key, old_value, new_value)
  if key != self.clock_key or !istable(old_value) or !istable(new_value) then return end
  if old_value.serial == new_value.serial then return end

  local timestamp = self:read_clock(new_value)

  self.last_minute = math.floor(timestamp / 60)

  --- Called on the client when the server has set the game clock to another moment, after
  -- the new clock has arrived. This is the client-side run of the hook that the server runs
  -- when it sets the clock. The rollover hooks carry on from the new time.
  -- @param timestamp [Number The game time the clock has been set to, in game seconds
  --   since midnight of 1 January 1970]
  -- @param old_timestamp [Number The game time the clock showed before it was set]
  hook.Run('GameTimeSet', timestamp, self:read_clock(old_value))
end

--- Puts the clock at the right end of the button bar of the tab menu.
-- @param menu [Panel the tab menu]
function GameTime:AddTabMenuItems(menu)
  local bar = menu.button_panel

  if !IsValid(bar) then return end

  local clock = vgui.Create('fl_gametime_clock', bar)
  clock:SetSize(math.scale(420), bar:GetTall())
  clock:SetPos(bar:GetWide() - clock:GetWide() - math.scale(16), 0)

  menu.gametime_clock = clock
end
