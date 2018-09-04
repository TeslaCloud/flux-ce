local flPlayer = {}
flPlayer.DisplayName = "Flux Player"
DEFINE_BASECLASS("player_default")

local modelList = {}

for k, v in pairs(player_manager.AllValidModels()) do
  modelList[v:lower()] = k
end

flPlayer.loadout = {
  "weapon_fists"
}

-- Called when the data tables are setup.
function flPlayer:SetupDataTables()
  if (!self.Player or !self.Player.DTVar) then
    return
  end

  self.Player:DTVar("Bool", BOOL_INITIALIZED, "Initialized")

  hook.run("PlayerSetupDataTables", self.Player)
end

-- Called on player spawn to determine which hand model to use.
function flPlayer:GetHandsModel()
  local playerModel = string.lower(self.Player:GetModel())

  if (modelList[playerModel]) then
    return player_manager.TranslatePlayerHands(modelList[playerModel])
  end

  for k, v in pairs(modelList) do
    if (string.find(string.gsub(playerModel, "_", ""), v)) then
      modelList[playerModel] = v

      break
    end
  end

  return player_manager.TranslatePlayerHands(modelList[playerModel])
end

-- Called after view model is drawn.
function flPlayer:PostDrawViewModel(viewmodel, weapon)
  if (weapon.UseHands or !weapon:IsScripted()) then
    local handsEntity = fl.client:GetHands()

    if (IsValid(handsEntity)) then
      handsEntity:DrawModel()
    end
  end
end

function flPlayer:Loadout()
  self.Player:StripWeapons()

  for k, v in pairs(self.loadout) do
    self.Player:Give(v)
  end

  self.Player:SelectWeapon(self.loadout[1])
end

player_manager.RegisterClass("flPlayer", flPlayer, "player_default")
