local flux_player       = {}
flux_player.DisplayName = 'Flux Player'
DEFINE_BASECLASS('player_default')

local model_list        = {}

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

  hook.run('PlayerSetupDataTables', self.Player)
end

--- Determines which hands model to use for the player's current model.
-- @return [Map hands info with the model, skin and body keys]
function flux_player:GetHandsModel()
  local player_model = string.lower(self.Player:GetModel())

  if model_list[player_model] then
    return player_manager.TranslatePlayerHands(model_list[player_model])
  end

  for k, v in pairs(model_list) do
    if string.find(string.gsub(player_model, '_', ''), v) then
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
  hook.run('PostPlayerLoadout', self.Player, self.loadout)
end

player_manager.RegisterClass('flux_player', flux_player, 'player_default')
