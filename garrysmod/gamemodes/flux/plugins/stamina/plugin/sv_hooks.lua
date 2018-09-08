Stamina.running = Stamina.running or {}
Stamina.timer_ids = Stamina.timer_ids or {}

local drain_scale = 4
local regen_scale = 2
local max_stamina = 100

function Stamina:OnActiveCharacterSet(player, character)
  character.stamina = character.stamina or 100
  player:set_nv('stamina', character.stamina)
end

function Stamina:set_stamina(player, character, stamina)
  character.stamina = stamina
  player:set_nv('stamina', stamina)
end

function Stamina:get_stamina(character)
  return character.stamina
end

function Stamina:start_running(player, prevent_drain)
  local char = IsValid(player) and player:GetCharacter()

  if !char then return end

  local steam_id = player:SteamID()
  local id = 'stam_run_'..steam_id

  timer.Pause('stam_regen_'..steam_id)

  if !prevent_drain and !self.running[steam_id] then
    if !timer.Exists(id) then
      table.insert(self.timer_ids, id)

      timer.Create(id, 0.2, 0, function()
        if IsValid(player) and player:GetActiveCharacterID() == char.id then
          Stamina:set_stamina(player, char, math.Clamp(char.stamina - 1 * drain_scale, 0, max_stamina))

          if char.stamina == 0 then
            timer.Pause(id)
          end
        else
          timer.Destroy(id)
          self.running[steam_id] = false
        end
      end)
    else
      timer.UnPause(id)
    end

    self.running[steam_id] = true
  end
end

function Stamina:stop_running(player, prevent_regen)
  local char = IsValid(player) and player:GetCharacter()

  if !char then return end

  local steam_id = player:SteamID()
  local id = 'stam_regen_'..steam_id

  timer.Pause('stam_run_'..steam_id)

  if !prevent_regen and self.running[steam_id] != false then
    if !timer.Exists(id) then
      table.insert(self.timer_ids, id)
  
      timer.Create(id, 0.2, 0, function()
        if IsValid(player) and player:GetActiveCharacterID() == char.id then
          Stamina:set_stamina(player, char, math.Clamp(char.stamina + 1 * regen_scale, 0, max_stamina))

          if char.stamina == max_stamina then
            timer.Pause(id)
          end
        else
          timer.Destroy(id)
          self.running[steam_id] = false
        end
      end)
    else
      timer.UnPause(id)
    end

    self.running[steam_id] = false
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

  local char = player:GetCharacter()

  if char and char.stamina == 0 then
    player:SetRunSpeed(player:GetWalkSpeed())
  else
    player:SetRunSpeed(config.Get("run_speed"))
  end
end

function Stamina:OnReloaded()
  for k, v in ipairs(self.timer_ids) do
    if timer.Exists(v) then
      timer.Destroy(v)
    end
  end
end
