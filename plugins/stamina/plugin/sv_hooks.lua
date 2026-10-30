--- Server-side hooks of the Stamina plugin: they track which players are running, slow them
-- down as their stamina runs out and save it with their character.

local config_get = Config.get
local timer_exists = timer.Exists
local timer_remove = timer.Remove

local jump_penalty = config_get('stamina_jump_penalty', 25)
local max_stamina = config_get('stamina_max', 100)
local regen_delay = config_get('stamina_regen_delay', 3)
local slowdown_threshold = config_get('stamina_slowdown_threshold', 0)
local persistent = config_get('stamina_persistent', false)

--- Returns the stamina below which a running player is slowed down, as set by the
-- 'stamina_slowdown_threshold' config.
-- @return [Number stamina points; 0 when the gradual slowdown is off]
local function get_slowdown_start()
  return max_stamina * slowdown_threshold * 0.01
end

--- Returns the run speed a player should have with the given stamina. An exhausted player
-- runs at their walk speed. With the 'stamina_slowdown_threshold' config set, the speed falls
-- from the 'flow_run_speed' config to the walk speed as the stamina goes from the threshold to
-- zero; without it the player keeps the full run speed until they are exhausted.
-- @param actor [Player]
-- @param stamina [Number current stamina of the player]
-- @return [Number run speed]
local function get_run_speed(actor, stamina)
  local walk_speed = actor:GetWalkSpeed()
  local run_speed = config_get('flow_run_speed')
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
-- slowed down by the 'stamina_slowdown_threshold' config may be too slow for `Player:running`,
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

--- Keeps the stamina settings that the hooks cache in sync with changes of their config keys.
-- @param key [String config key]
-- @param _old_value [Any]
-- @param new_value [Any]
function Stamina:ConfigChanged(key, _old_value, new_value)
  if key == 'stamina_max' then
    max_stamina = new_value
  elseif key == 'stamina_jump_penalty' then
    jump_penalty = new_value
  elseif key == 'stamina_regen_delay' then
    regen_delay = new_value
  elseif key == 'stamina_slowdown_threshold' then
    slowdown_threshold = new_value
  elseif key == 'stamina_persistent' then
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
-- 'stamina_persistent' config is on, gives the player the stamina that was saved with the
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

--- Forgets that the stamina of a player belongs to the character they drop, so that it is
-- no longer written into that character.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function Stamina:ActiveCharacterCleared(owner, _character)
  owner.stamina_character_id = nil
end

--- Writes the stamina of the player into the generic data of their character before it is
-- saved, under the 'stamina' key. Nothing is kept for a dead player, so that the character
-- is loaded with full stamina next time, or while the 'stamina_persistent' config is off: a
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
    actor:SetJumpPower(config_get('flow_jump_power'))
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
  local steam_id = actor:SteamID64()

  for _, timer_id in ipairs({ 'stam_run_'..steam_id, 'stam_regen_'..steam_id }) do
    timer_remove(timer_id)
    table.RemoveByValue(self.timer_ids, timer_id)
  end
end

--- Removes every stamina timer when the code is reloaded, and forgets what the players
-- were doing so that the timers are started again.
function Stamina:OnReloaded()
  for _, timer_id in ipairs(self.timer_ids) do
    if timer_exists(timer_id) then
      timer_remove(timer_id)
    end
  end

  self.timer_ids = {}

  for _, client in player.Iterator() do
    client.was_running = false
    client.stamina_regenerating = false
  end
end
