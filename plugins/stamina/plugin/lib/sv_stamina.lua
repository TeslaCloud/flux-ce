--- Server side of the Stamina library: the stamina of a player, whether it may drain or
-- regenerate, and the timers that drain it while the player runs and regenerate it while
-- they do not.

local IsValid = IsValid
local config_get = Config.get
local timer_exists = timer.Exists
local timer_pause = timer.Pause
local timer_remove = timer.Remove

if !Stamina then
  PLUGIN:set_global('Stamina')
end

Stamina.timer_ids = Stamina.timer_ids or {}

--- Stops the stamina regeneration of a player. It starts again once the 'stamina_regen_delay'
-- config has passed, unless the player is running by then.
-- @param target [Player]
local function delay_regen(target)
  target.stamina_regenerating = false
  target.standing_since = CurTime()

  timer_pause('stam_regen_'..target:SteamID64())
end

--- Returns how much stamina a running player loses on a drain tick: the 'stamina_drain_scale'
-- config, scaled by the GetStaminaDrainScale hook and, if the 'stamina_health_drain_scale'
-- config is set, by the health the player is missing.
-- @param target [Player]
-- @return [Number stamina points]
local function get_drain_amount(target)
  --- Lets plugins scale how fast a running player's stamina drains.
  -- Called on every drain tick, five times a second.
  -- @param target [Player The player who is running]
  -- @return [Number Multiplier of the drain rate; 1 when nothing is returned]
  local adjust_scale = Plugin.call('GetStaminaDrainScale', target) or 1
  local max_health = target:GetMaxHealth()
  local health_drain_scale = config_get('stamina_health_drain_scale', 0)

  if health_drain_scale > 0 and max_health > 0 then
    local missing_health = 1 - math.Clamp(target:Health() / max_health, 0, 1)

    adjust_scale *= 1 + missing_health * health_drain_scale
  end

  return 4 * config_get('stamina_drain_scale', 1) * adjust_scale
end

--- Returns how much stamina a player recovers on a regeneration tick: the 'stamina_regen_scale'
-- config, scaled by the GetStaminaRegenScale hook and, while the player is crouching, by
-- the 'stamina_crouch_regen_scale' config.
-- @param target [Player]
-- @return [Number stamina points]
local function get_regen_amount(target)
  --- Lets plugins scale how fast a player's stamina regenerates.
  -- Called on every regeneration tick, five times a second.
  -- @param target [Player The player who is recovering]
  -- @return [Number Multiplier of the regeneration rate; 1 when nothing is returned]
  local adjust_scale = Plugin.call('GetStaminaRegenScale', target) or 1

  if target:Crouching() then
    adjust_scale *= config_get('stamina_crouch_regen_scale', 1)
  end

  return 2 * config_get('stamina_regen_scale', 1) * adjust_scale
end

--- Sets the player's stamina, clamped between 0 and the 'stamina_max' config value, and
-- networks it. Serverside only.
-- @param target [Player]
-- @param stamina [Number]
function Stamina:set_stamina(target, stamina)
  target:set_nv('stamina', math.Clamp(stamina, 0, config_get('stamina_max', 100)))
end

--- Returns the player's current stamina. Serverside only.
-- @param target [Player]
-- @return [Number current stamina, or the 'stamina_max' config value if it was never set]
function Stamina:get_stamina(target)
  return target:get_nv('stamina', config_get('stamina_max', 100))
end

--- Checks whether the player's stamina may drain right now. It never drains for players who
-- are dead, noclipping or in observer mode, and the ShouldDrainStamina hook can keep
-- it from draining for anyone else. Serverside only.
-- @param target [Player]
-- @return [Boolean]
function Stamina:can_drain(target)
  if !IsValid(target) or !target:Alive() then
    return false
  end

  if target:get_nv('observer') or (target:GetMoveType() == MOVETYPE_NOCLIP and !target:InVehicle()) then
    return false
  end

  --- Lets plugins keep a player's stamina from draining. Called on the server before
  -- stamina is taken from a player who is alive and neither noclipping nor in observer
  -- mode: on every drain tick of a running player, five times a second, when a jump costs
  -- stamina and from `Stamina:drain`.
  -- @param target [Player The player whose stamina is about to drain]
  -- @return [Boolean Return false to keep the stamina as it is]
  local should_drain = Plugin.call('ShouldDrainStamina', target)

  return should_drain != false
end

--- Checks whether the player's stamina may regenerate right now, which the
-- ShouldRegenerateStamina hook decides. Serverside only.
-- @param target [Player]
-- @return [Boolean]
function Stamina:can_regenerate(target)
  --- Lets plugins keep a player's stamina from regenerating. Called on the server on every
  -- regeneration tick of a player whose stamina is not full, five times a second.
  -- @param target [Player The player whose stamina is about to regenerate]
  -- @return [Boolean Return false to keep the stamina as it is]
  local should_regenerate = Plugin.call('ShouldRegenerateStamina', target)

  return should_regenerate != false
end

--- Takes stamina from the player and delays its regeneration by the 'stamina_regen_delay'
-- config, the way jumping does. Nothing is taken when the stamina may not drain.
-- Serverside only.
-- ```
-- if Stamina:get_stamina(actor) >= 10 then
--   Stamina:drain(actor, 10)
-- end
-- ```
-- @param target [Player]
-- @param amount [Number stamina points to take]
-- @return [Boolean whether the stamina was taken]
-- @see [Stamina:can_drain]
function Stamina:drain(target, amount)
  if !self:can_drain(target) then
    return false
  end

  self:set_stamina(target, self:get_stamina(target) - amount)

  delay_regen(target)

  return true
end

--- Pauses the player's stamina regeneration. Unless prevent_drain is set, it also runs the
-- PlayerStartedRunning hook on the server and on the player's client, and starts draining
-- stamina every 0.2 seconds. Serverside only.
-- @param target [Player]
-- @param prevent_drain=false [Boolean only pause the regeneration]
function Stamina:start_running(target, prevent_drain)
  if !IsValid(target) then return end

  target.stamina_regenerating = false

  local steam_id = target:SteamID64()
  local id = 'stam_run_'..steam_id

  timer_pause('stam_regen_'..steam_id)

  if prevent_drain then return end

  --- Called when a player starts running and their stamina begins to drain.
  -- The hook is run on the server and then on the client of the player.
  -- @param target [Player The player who started running]
  hook.Run('PlayerStartedRunning', target)
  hook.run_client(target, 'PlayerStartedRunning', target)

  if !timer_exists(id) then
    table.insert(self.timer_ids, id)

    timer.Create(id, 0.2, 0, function()
      if IsValid(target) then
        if self:can_drain(target) then
          self:set_stamina(target, self:get_stamina(target) - get_drain_amount(target))
        end
      else
        timer_remove(id)
      end
    end)
  else
    timer.UnPause(id)
  end
end

--- Pauses the player's stamina drain. With prevent_regen set it runs the PlayerStoppedRunning
-- hook on the server and on the player's client; without it, it starts regenerating
-- stamina every 0.2 seconds instead, until the stamina is full. Serverside only.
-- @param target [Player]
-- @param prevent_regen=false [Boolean do not start the regeneration]
function Stamina:stop_running(target, prevent_regen)
  if !IsValid(target) then return end

  local steam_id = target:SteamID64()
  local id = 'stam_regen_'..steam_id

  timer_pause('stam_run_'..steam_id)

  if prevent_regen then
    --- Called when a player stops running and their stamina stops draining.
    -- Regeneration only starts once the regeneration delay has passed. The hook is run
    -- on the server and then on the client of the player.
    -- @param target [Player The player who stopped running]
    hook.Run('PlayerStoppedRunning', target)
    hook.run_client(target, 'PlayerStoppedRunning', target)

    return
  end

  target.stamina_regenerating = true

  if !timer_exists(id) then
    table.insert(self.timer_ids, id)

    timer.Create(id, 0.2, 0, function()
      if IsValid(target) then
        local max_stamina = config_get('stamina_max', 100)
        local stamina = self:get_stamina(target)

        if stamina < max_stamina and self:can_regenerate(target) then
          stamina += get_regen_amount(target)

          self:set_stamina(target, stamina)
        end

        if stamina >= max_stamina then
          target.stamina_regenerating = false

          timer_pause(id)
        end
      else
        timer_remove(id)
      end
    end)
  else
    timer.UnPause(id)
  end
end
