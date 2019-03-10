local flPlayer = {}
flPlayer.DisplayName = 'Flux Player'
DEFINE_BASECLASS('player_default')

local model_list = {}

for k, v in pairs(player_manager.AllValidModels()) do
  model_list[v:lower()] = k
end

flPlayer.loadout = {
  'weapon_fists'
}

-- Called when the data tables are setup.
function flPlayer:SetupDataTables()
  if !self.Player or !self.Player.DTVar then
    return
  end

  self.Player:DTVar('Bool', BOOL_INITIALIZED, 'Initialized')

  hook.run('PlayerSetupDataTables', self.Player)
end

-- Called on player spawn to determine which hand model to use.
function flPlayer:GetHandsModel()
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

-- Called after view model is drawn.
function flPlayer:PostDrawViewModel(viewmodel, weapon)
  if weapon.UseHands or !weapon:IsScripted() then
    local hands_entity = PLAYER:GetHands()

    if IsValid(hands_entity) then
      hands_entity:DrawModel()
    end
  end
end

function flPlayer:Loadout()
  hook.run('PostPlayerLoadout', self.Player, self.loadout)
end

player_manager.RegisterClass('flPlayer', flPlayer, 'player_default')
