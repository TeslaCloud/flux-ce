--- Server side of the Stamina plugin: tracks which players are running, drains or
-- regenerates their stamina on timers, slows them down as it runs out and saves it with
-- their character.

Stamina.running = Stamina.running or {}
Stamina.timer_ids = Stamina.timer_ids or {}

local drain_scale = 4 * Config.get('stam_drain_scale', 1)
local regen_scale = 2 * Config.get('stam_regen_scale', 1)
local jump_penalty = Config.get('stam_jump_penalty', 25)
local max_stamina = Config.get('stam_max', 100)
local regen_delay = Config.get('stam_regen_delay', 3)
local health_drain_scale = Config.get('stam_health_drain_scale', 0)
local crouch_regen_scale = Config.get('stam_crouch_regen_scale', 1)
local slowdown_threshold = Config.get('stam_slowdown_threshold', 0)
local persistent = Config.get('stam_persistent', false)

--- Returns the stamina below which a running player is slowed down, as set by the
-- 'stam_slowdown_threshold' config.
-- @return [Number stamina points; 0 when the gradual slowdown is off]
local function get_slowdown_start()
  return max_stamina * slowdown_threshold * 0.01
end

--- Returns the run speed a player should have with the given stamina. An exhausted player
-- runs at their walk speed. With the 'stam_slowdown_threshold' config set, the speed falls
-- from the 'run_speed' config to the walk speed as the stamina goes from the threshold to
-- zero; without it the player keeps the full run speed until they are exhausted.
-- @param actor [Player]
-- @param stamina [Number current stamina of the player]
-- @return [Number run speed]
local function get_run_speed(actor, stamina)
  local walk_speed = actor:GetWalkSpeed()
  local run_speed = Config.get('run_speed')
  local slowdown_start = get_slowdown_start()

  if stamina <= 1 then
    return walk_speed
  end

  if stamina >= slowdown_start then
    return run_speed
  end

  return Lerp(stamina / slowdown_start, walk_speed, run_speed)
end

--- Checks whether a player is running as far as stamina is concerned. A player who is
-- slowed down by the 'stam_slowdown_threshold' config may be too slow for `Player:running`,
-- so they also count as running while they hold the sprint key and move on foot at about
-- their walk speed or faster. This keeps their stamina draining until they stop sprinting.
-- @param actor [Player]
-- @param stamina [Number current stamina of the player]
-- @return [Boolean]
local function is_running(actor, stamina)
  if actor:running() then
    return true
  end

  if stamina >= get_slowdown_start() then
    return false
  end

  return actor:Alive() and !actor:Crouching() and actor:GetMoveType() == MOVETYPE_WALK
    and actor:KeyDown(IN_SPEED) and actor:GetVelocity():Length2DSqr() > (actor:GetWalkSpeed() * 0.9) ^ 2
end

--- Stops the stamina regeneration of a player. It starts again once the 'stam_regen_delay'
-- config has passed, unless the player is running by then.
-- @param target [Player]
local function delay_regen(target)
  target.stamina_regenerating = false
  target.standing_since = CurTime()

  timer.Pause('stam_regen_'..target:SteamID())
end

--- Returns how much stamina a running player loses on a drain tick: the 'stam_drain_scale'
-- config, scaled by the StaminaAdjustDrainScale hook and, if the 'stam_health_drain_scale'
-- config is set, by the health the player is missing.
-- @param target [Player]
-- @return [Number stamina points]
local function get_drain_amount(target)
  --- Lets plugins scale how fast a running player's stamina drains.
  -- Called on every drain tick, five times a second.
  -- @param target [Player The player who is running]
  -- @return [Number Multiplier of the drain rate; 1 when nothing is returned]
  local adjust_scale = Plugin.call('StaminaAdjustDrainScale', target) or 1
  local max_health = target:GetMaxHealth()

  if health_drain_scale > 0 and max_health > 0 then
    local missing_health = 1 - math.Clamp(target:Health() / max_health, 0, 1)

    adjust_scale = adjust_scale * (1 + missing_health * health_drain_scale)
  end

  return drain_scale * adjust_scale
end

--- Returns how much stamina a player recovers on a regeneration tick: the 'stam_regen_scale'
-- config, scaled by the StaminaAdjustRegenScale hook and, while the player is crouching, by
-- the 'stam_crouch_regen_scale' config.
-- @param target [Player]
-- @return [Number stamina points]
local function get_regen_amount(target)
  --- Lets plugins scale how fast a player's stamina regenerates.
  -- Called on every regeneration tick, five times a second.
  -- @param target [Player The player who is recovering]
  -- @return [Number Multiplier of the regeneration rate; 1 when nothing is returned]
  local adjust_scale = Plugin.call('StaminaAdjustRegenScale', target) or 1

  if target:Crouching() then
    adjust_scale = adjust_scale * crouch_regen_scale
  end

  return regen_scale * adjust_scale
end

--- Keeps the cached stamina settings in sync with changes of the 'stam_' config keys.
-- @param key [String config key]
-- @param old_value [Any]
-- @param new_value [Any]
function Stamina:OnConfigSet(key, old_value, new_value)
  if key == 'stam_drain_scale' then
    drain_scale = 4 * new_value
  elseif key == 'stam_regen_scale' then
    regen_scale = 2 * new_value
  elseif key == 'stam_max' then
    max_stamina = new_value
  elseif key == 'stam_jump_penalty' then
    jump_penalty = new_value
  elseif key == 'stam_regen_delay' then
    regen_delay = new_value
  elseif key == 'stam_health_drain_scale' then
    health_drain_scale = new_value
  elseif key == 'stam_crouch_regen_scale' then
    crouch_regen_scale = new_value
  elseif key == 'stam_slowdown_threshold' then
    slowdown_threshold = new_value
  elseif key == 'stam_persistent' then
    persistent = new_value
  end
end

--- Refills the player's stamina when they spawn. When a character is loaded, the stamina
-- saved with it is applied afterwards.
-- @param actor [Player]
-- @see [Stamina:PostCharacterLoaded]
function Stamina:PostPlayerSpawn(actor)
  actor:set_nv('stamina', max_stamina)
end

--- Remembers which character the stamina of the player belongs to and, if the
-- 'stam_persistent' config is on, gives the player the stamina that was saved with the
-- character. A character without saved stamina keeps the full stamina it spawned with.
-- Only runs when the Characters plugin is loaded.
-- @param owner [Player]
-- @param character [Character the character that has been loaded]
function Stamina:PostCharacterLoaded(owner, character)
  if !Characters then return end

  owner.stamina_character_id = tonumber(character.id)

  if persistent then
    local saved_stamina = tonumber(Characters.get_custom_data(character, 'stamina'))

    if saved_stamina then
      self:set_stamina(owner, saved_stamina)
    end
  end
end

--- Writes the stamina of the player into the generic data of their character before it is
-- saved, under the 'stamina' key. Nothing is kept for a dead player, so that the character
-- is loaded with full stamina next time, or while the 'stam_persistent' config is off: a
-- value that was saved before is then cleared once, and nothing is written as long as
-- there is none. A player counts as dead once their health is gone, because the save that
-- follows a death runs while `Player:Alive` still returns true.
-- Only runs when the Characters plugin is loaded.
-- @param owner [Player]
-- @param character [Character the character that is being saved]
function Stamina:SaveCharacterData(owner, character)
  if !Characters or owner:IsBot() then return end
  if !owner.stamina_character_id or owner.stamina_character_id != tonumber(character.id) then return end

  if persistent and owner:Alive() and owner:Health() > 0 then
    Characters.set_custom_data(character, 'stamina', math.Round(self:get_stamina(owner)))
  elseif Characters.get_custom_data(character, 'stamina') != nil then
    Characters.set_custom_data(character, 'stamina', nil)
  end
end

--- Starts and stops stamina drain and regeneration depending on whether the player is
-- running, and limits their jump power and run speed while stamina is low.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function Stamina:PlayerThink(actor, cur_time)
  local cur_stam = actor:get_nv('stamina', max_stamina)

  if is_running(actor, cur_stam) and (actor:OnGround() or actor:WaterLevel() >= 1) then
    if !actor.was_running then
      self:start_running(actor)
      actor.was_running = true
    end
  else
    if actor.was_running then
      self:stop_running(actor, true)
      actor.was_running = false
      actor.standing_since = cur_time
    elseif !actor.stamina_regenerating and cur_stam < max_stamina
    and (cur_time - (actor.standing_since or 0)) > regen_delay then
      self:stop_running(actor)
    end
  end

  if cur_stam < jump_penalty then
    actor:SetJumpPower(1)
  else
    actor:SetJumpPower(Config.get('jump_power'))
  end

  actor:SetRunSpeed(get_run_speed(actor, cur_stam))
end

--- Takes the jump penalty off the player's stamina and delays its regeneration when they
-- jump off the ground. Does nothing if their stamina is below the penalty.
-- @param actor [Player]
-- @param key [Number IN_ enum of the pressed key]
function Stamina:KeyPress(actor, key)
  if key == IN_JUMP and actor:OnGround() and actor:GetMoveType() == MOVETYPE_WALK then
    if self:get_stamina(actor) < jump_penalty then return end

    self:drain(actor, jump_penalty)
  end
end

--- Removes the stamina timers of a player who leaves the server.
-- @param actor [Player]
function Stamina:PlayerDisconnected(actor)
  local steam_id = actor:SteamID()

  for k, v in ipairs({ 'stam_run_'..steam_id, 'stam_regen_'..steam_id }) do
    timer.Remove(v)
    table.RemoveByValue(self.timer_ids, v)
  end

  self.running[steam_id] = nil
end

--- Removes every stamina timer when the code is reloaded, and forgets what the players
-- were doing so that the timers are started again.
function Stamina:OnReloaded()
  for k, v in ipairs(self.timer_ids) do
    if timer.Exists(v) then
      timer.Remove(v)
    end
  end

  self.timer_ids = {}

  for k, v in player.Iterator() do
    v.was_running = false
    v.stamina_regenerating = false
  end
end

--- Sets the player's stamina, clamped between 0 and the 'stam_max' config value, and
-- networks it. Serverside only.
-- @param target [Player]
-- @param stamina [Number]
function Stamina:set_stamina(target, stamina)
  return target:set_nv('stamina', math.Clamp(stamina, 0, max_stamina))
end

--- Returns the player's current stamina. Serverside only.
-- @param target [Player]
-- @return [Number current stamina, or the 'stam_max' config value if it was never set]
function Stamina:get_stamina(target)
  return target:get_nv('stamina', max_stamina)
end

--- Checks whether the player's stamina may drain right now. It never drains for players who
-- are dead, noclipping or in observer mode, and the PlayerShouldStaminaDrain hook can keep
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
  local should_drain = Plugin.call('PlayerShouldStaminaDrain', target)

  return should_drain != false
end

--- Checks whether the player's stamina may regenerate right now, which the
-- PlayerShouldStaminaRegenerate hook decides. Serverside only.
-- @param target [Player]
-- @return [Boolean]
function Stamina:can_regenerate(target)
  --- Lets plugins keep a player's stamina from regenerating. Called on the server on every
  -- regeneration tick of a player whose stamina is not full, five times a second.
  -- @param target [Player The player whose stamina is about to regenerate]
  -- @return [Boolean Return false to keep the stamina as it is]
  local should_regenerate = Plugin.call('PlayerShouldStaminaRegenerate', target)

  return should_regenerate != false
end

--- Takes stamina from the player and delays its regeneration by the 'stam_regen_delay'
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
-- PlayerStartRunning hook on the server and on the player's client, and starts draining
-- stamina every 0.2 seconds. Serverside only.
-- @param target [Player]
-- @param prevent_drain=false [Boolean only pause the regeneration]
function Stamina:start_running(target, prevent_drain)
  if !IsValid(target) then return end

  target.stamina_regenerating = false

  local steam_id = target:SteamID()
  local id = 'stam_run_'..steam_id

  timer.Pause('stam_regen_'..steam_id)

  if !prevent_drain then
    --- Called when a player starts running and their stamina begins to drain.
    -- The hook is run on the server and then on the client of the player.
    -- @param target [Player The player who started running]
    hook.Run('PlayerStartRunning', target)
    hook.run_client(target, 'PlayerStartRunning', target)
  end

  if !prevent_drain then
    self.running[steam_id] = true

    if !timer.Exists(id) then
      table.insert(self.timer_ids, id)

      timer.Create(id, 0.2, 0, function()
        if IsValid(target) then
          if self:can_drain(target) then
            self:set_stamina(target, self:get_stamina(target) - get_drain_amount(target))
          end
        else
          timer.Remove(id)
          self.running[steam_id] = false
        end
      end)
    else
      timer.UnPause(id)
    end
  end
end

--- Pauses the player's stamina drain. With prevent_regen set it runs the PlayerStopRunning
-- hook on the server and on the player's client; without it, it starts regenerating
-- stamina every 0.2 seconds instead, until the stamina is full. Serverside only.
-- @param target [Player]
-- @param prevent_regen=false [Boolean do not start the regeneration]
function Stamina:stop_running(target, prevent_regen)
  if !IsValid(target) then return end

  local steam_id = target:SteamID()
  local id = 'stam_regen_'..steam_id

  timer.Pause('stam_run_'..steam_id)

  self.running[steam_id] = false

  if prevent_regen then
    --- Called when a player stops running and their stamina stops draining.
    -- Regeneration only starts once the regeneration delay has passed. The hook is run
    -- on the server and then on the client of the player.
    -- @param target [Player The player who stopped running]
    hook.Run('PlayerStopRunning', target)
    hook.run_client(target, 'PlayerStopRunning', target)
  end

  if !prevent_regen then
    target.stamina_regenerating = true

    if !timer.Exists(id) then
      table.insert(self.timer_ids, id)

      timer.Create(id, 0.2, 0, function()
        if IsValid(target) then
          local stamina = self:get_stamina(target)

          if stamina < max_stamina and self:can_regenerate(target) then
            stamina = stamina + get_regen_amount(target)

            self:set_stamina(target, stamina)
          end

          if stamina >= max_stamina then
            target.stamina_regenerating = false

            timer.Pause(id)
          end
        else
          timer.Remove(id)
        end
      end)
    else
      timer.UnPause(id)
    end
  end
end
