config.set('stam_drain_scale', 1)
config.set('stam_regen_scale', 1)
config.set('stam_jump_penalty', 25)
config.set('stam_max', 100)

Stamina.running = Stamina.running or {}
Stamina.timer_ids = Stamina.timer_ids or {}

local drain_scale = 4 * config.get('stam_drain_scale', 1)
local regen_scale = 2 * config.get('stam_regen_scale', 1)
local jump_penalty = config.get('stam_jump_penalty', 25)
local max_stamina = config.get('stam_max', 100)

function Stamina:OnConfigSet(key, old_value, new_value)
  if key == 'stam_drain_scale' then
    drain_scale = 4 * new_value
  elseif key == 'stam_regen_scale' then
    regen_scale = 2 * new_value
  elseif key == 'stam_max' then
    max_stamina = new_value
  elseif key == 'stam_jump_penalty' then
    jump_penalty = new_value
  end
end

function Stamina:OnActiveCharacterSet(player)
  return player:set_nv('stamina', 100)
end

function Stamina:set_stamina(player, stamina)
  return player:set_nv('stamina', math.Clamp(stamina, 0, max_stamina))
end

function Stamina:get_stamina(player)
  return player:get_nv('stamina', 100)
end

function Stamina:start_running(player, prevent_drain)
  if !IsValid(player) then return end

  local steam_id = player:SteamID()
  local id = 'stam_run_'..steam_id

  timer.Pause('stam_regen_'..steam_id)

  if !prevent_drain and !self.running[steam_id] then
    if !timer.Exists(id) then
      table.insert(self.timer_ids, id)

      timer.Create(id, 0.2, 0, function()
        if IsValid(player) then
          local new_stam = player:get_nv('stamina', 100) - 1 * drain_scale * (plugin.call('StaminaAdjustDrainScale', player) or 1)

          self:set_stamina(player, new_stam)

          if new_stam <= 0 then
            timer.Pause(id)
          end

          self.running[steam_id] = true
        else
          timer.Destroy(id)
          self.running[steam_id] = false
        end
      end)
    else
      timer.UnPause(id)
    end
  end
end

function Stamina:stop_running(player, prevent_regen)
  if !IsValid(player) then return end

  local steam_id = player:SteamID()
  local id = 'stam_regen_'..steam_id

  timer.Pause('stam_run_'..steam_id)

  if !prevent_regen and self.running[steam_id] != false then
    if !timer.Exists(id) then
      table.insert(self.timer_ids, id)
  
      timer.Create(id, 0.2, 0, function()
        if IsValid(player) then
          local new_stam = player:get_nv('stamina', 100) + 1 * regen_scale * (plugin.call('StaminaAdjustRegenScale', player) or 1)

          self:set_stamina(player, new_stam)

          if new_stam >= max_stamina then
            timer.Pause(id)
          end

          self.running[steam_id] = false
        else
          timer.Destroy(id)
          self.running[steam_id] = false
        end
      end)
    else
      timer.UnPause(id)
    end
  end
end

function Stamina:PlayerThink(player, cur_time)
  if player:running() then
    if !player.was_running then
      self:start_running(player)
      player.was_running = true
    end
  else
    if player.was_running then
      self:stop_running(player, true)

      timer.Simple(1, function()
        -- Delay stamina regen by 1 second.
        if IsValid(player) and !player.was_running then
          self:stop_running(player)
        end
      end)
      player.was_running = false
    end
  end

  if !player:OnGround() then
    if player.was_on_ground then
      self:set_stamina(player, player:get_nv('stamina', 100) - jump_penalty)
      self:start_running(player, true)
    end

    player.was_on_ground = false
  elseif !player.was_on_ground then
    player.was_on_ground = true
    self:stop_running(player, true)
    timer.Simple(1, function()
      if IsValid(player) and !player.was_running and player.was_on_ground then
        self:stop_running(player)
      end
    end)
  end

  if player:get_nv('stamina', 100) <= 1 then
    player:SetRunSpeed(player:GetWalkSpeed())
    player:SetJumpPower(0)
  else
    player:SetRunSpeed(config.get('run_speed'))
    player:SetJumpPower(config.get('jump_power'))
  end
end

function Stamina:OnReloaded()
  for k, v in ipairs(self.timer_ids) do
    if timer.Exists(v) then
      timer.Destroy(v)
    end
  end
end
