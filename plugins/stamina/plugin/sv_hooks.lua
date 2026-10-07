Stamina.running = Stamina.running or {}
Stamina.timer_ids = Stamina.timer_ids or {}

local drain_scale = 4 * Config.get('stam_drain_scale', 1)
local regen_scale = 2 * Config.get('stam_regen_scale', 1)
local jump_penalty = Config.get('stam_jump_penalty', 25)
local max_stamina = Config.get('stam_max', 100)
local regen_delay = Config.get('stam_regen_delay', 3)

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
  end
end

--- Refills the player's stamina when they spawn.
-- @param actor [Player]
function Stamina:PostPlayerSpawn(actor)
  actor:set_nv('stamina', max_stamina)
end

--- Starts and stops stamina drain and regeneration depending on whether the player is
-- running, and limits their jump power and run speed while stamina is low.
-- @param actor [Player]
-- @param cur_time [Number CurTime() of the tick]
function Stamina:PlayerThink(actor, cur_time)
  if actor:running() and (actor:OnGround() or actor:WaterLevel() >= 1) then -- We're doing 1 (Slightly Submerged) to prevent the player from jumping on the surface of the water to avoid stamina loss.
    if !actor.was_running then
      self:start_running(actor)
      actor.was_running = true
    end
  else
    if actor.was_running then
      self:stop_running(actor, true)
      actor.was_running = false
      actor.standing_since = cur_time
    elseif !actor.stamina_regenerating and (cur_time - (actor.standing_since or 0)) > regen_delay then
      self:stop_running(actor)
    end
  end

  local cur_stam = actor:get_nv('stamina', max_stamina)

  if cur_stam != max_stamina and actor.jumped_at and !actor.was_running then
    if cur_time - regen_delay > actor.jumped_at then
      self:stop_running(actor)
      actor.jumped_at = nil
    end
  end

  if cur_stam < jump_penalty then
    actor:SetJumpPower(1)
  else
    actor:SetJumpPower(Config.get('jump_power'))
  end

  if cur_stam <= 1 then
    actor:SetRunSpeed(actor:GetWalkSpeed())
  else
    actor:SetRunSpeed(Config.get('run_speed'))
  end
end

--- Takes the jump penalty off the player's stamina and pauses its regeneration when they
-- jump off the ground. Does nothing if their stamina is below the penalty.
-- @param actor [Player]
-- @param key [Number IN_ enum of the pressed key]
function Stamina:KeyPress(actor, key)
  if key == IN_JUMP and actor:OnGround() and actor:GetMoveType() == MOVETYPE_WALK then
    local cur_stam = actor:get_nv('stamina', max_stamina)

    if cur_stam < jump_penalty then return end

    self:set_stamina(actor, cur_stam - jump_penalty)
    self.stamina_regenerating = false
    timer.Pause('stam_regen_'..actor:SteamID())

    actor.jumped_at = CurTime()
  end
end

--- Removes every stamina timer when the code is reloaded.
function Stamina:OnReloaded()
  for k, v in ipairs(self.timer_ids) do
    if timer.Exists(v) then
      timer.Remove(v)
    end
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
    hook.Run('PlayerStartRunning', target)
    hook.run_client(target, 'PlayerStartRunning', target)
  end

  if !prevent_drain then
    self.running[steam_id] = true

    if !timer.Exists(id) then
      table.insert(self.timer_ids, id)

      timer.Create(id, 0.2, 0, function()
        if IsValid(target) then
          local new_stam = target:get_nv('stamina', max_stamina) - 1 * drain_scale * (Plugin.call('StaminaAdjustDrainScale', target) or 1)

          self:set_stamina(target, new_stam)

          if new_stam <= 0 then
            timer.Pause(id)
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
-- stamina every 0.2 seconds instead. Serverside only.
-- @param target [Player]
-- @param prevent_regen=false [Boolean do not start the regeneration]
function Stamina:stop_running(target, prevent_regen)
  if !IsValid(target) then return end

  local steam_id = target:SteamID()
  local id = 'stam_regen_'..steam_id

  timer.Pause('stam_run_'..steam_id)

  if prevent_regen then
    hook.Run('PlayerStopRunning', target)
    hook.run_client(target, 'PlayerStopRunning', target)
  end

  if !prevent_regen then
    self.running[steam_id] = false
    target.stamina_regenerating = true

    if !timer.Exists(id) then
      table.insert(self.timer_ids, id)

      timer.Create(id, 0.2, 0, function()
        if IsValid(target) then
          local new_stam = target:get_nv('stamina', max_stamina) + 1 * regen_scale * (Plugin.call('StaminaAdjustRegenScale', target) or 1)

          self:set_stamina(target, new_stam)

          if new_stam >= max_stamina then
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
