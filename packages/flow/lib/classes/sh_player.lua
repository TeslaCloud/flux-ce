--- The 'flux_player' player class, which Flux assigns to every player. It derives from the
-- 'player_default' class of Garry's Mod and passes the callbacks of the player class on to
-- Flux hooks: setting up the data tables runs `PlayerSetupDataTables`, and the loadout runs
-- `PostPlayerLoadout` with the default loadout of the class, the fists. It also picks the
-- hands model that matches the model of the player.

local flux_player       = {}
flux_player.DisplayName = 'Flux Player'
DEFINE_BASECLASS('player_default')

local model_list = {}

for k, v in pairs(player_manager.AllValidModels()) do
  model_list[v:lower()] = k
end

flux_player.loadout = {
  'weapon_fists'
}

--- Sets up the 'Initialized' data table variable of the player and runs the
-- 'PlayerSetupDataTables' hook.
function flux_player:SetupDataTables()
  if !self.Player or !self.Player.DTVar then
    return
  end

  self.Player:DTVar('Bool', BOOL_INITIALIZED, 'Initialized')

  --- Called on the server and the client when the data tables of a player are set up, right
  -- after Flux has added its own `Initialized` variable. Add the data table variables of your
  -- plugin to the player here with `DTVar`.
  -- @param target [Player the player whose data tables are being set up]
  hook.Run('PlayerSetupDataTables', self.Player)
end

--- Determines which hands model to use for the player's current model.
-- @return [Map hands info with the model, skin and body keys]
function flux_player:GetHandsModel()
  local player_model = string.lower(self.Player:GetModel())

  if model_list[player_model] then
    return player_manager.TranslatePlayerHands(model_list[player_model])
  end

  local stripped_model = string.gsub(player_model, '_', '')

  for k, v in pairs(model_list) do
    if string.find(stripped_model, v) then
      model_list[player_model] = v

      break
    end
  end

  return player_manager.TranslatePlayerHands(model_list[player_model])
end

--- Draws the hands of the local player after the view model has been drawn.
-- @param viewmodel [Entity]
-- @param weapon [Weapon]
function flux_player:PostDrawViewModel(viewmodel, weapon)
  if weapon.UseHands or !weapon:IsScripted() then
    local hands_entity = PLAYER:GetHands()

    if IsValid(hands_entity) then
      hands_entity:DrawModel()
    end
  end
end

--- Runs the 'PostPlayerLoadout' hook with the default loadout of the player class.
function flux_player:Loadout()
  --- Called on the server when a player gets their loadout after spawning. The handler of the
  -- Flux gamemode strips the weapons of the player, gives them the weapons of the default
  -- loadout and selects the first one; it does not run if a plugin or schema handler returns a
  -- non-nil value.
  -- @param actor [Player the player who has spawned]
  -- @param default_loadout [List<String> weapon classes of the default loadout]
  hook.Run('PostPlayerLoadout', self.Player, self.loadout)
end

player_manager.RegisterClass('flux_player', flux_player, 'player_default')
