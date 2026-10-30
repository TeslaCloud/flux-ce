--- The 'flux_player' player class, which Flux assigns to every player. It derives from the
-- 'player_default' class of Garry's Mod and passes the callbacks of the player class on to
-- Flux hooks: setting up the data tables runs `PlayerSetupDataTables`, and the loadout runs
-- `AdjustPlayerLoadout` with a copy of the default loadout of the class, the fists, before the
-- player is given it with `Player:give_loadout`. It also picks the
-- hands model that matches the model of the player. `BOOL_INITIALIZED` is the data table slot
-- of the `Initialized` variable, which marks the player as initialized.

enumerate 'BOOL_INITIALIZED'

local flux_player       = {}
flux_player.DisplayName = 'Flux Player'
DEFINE_BASECLASS('player_default')

local model_list = {}

for model_name, model_path in pairs(player_manager.AllValidModels()) do
  model_list[model_path:lower()] = model_name
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

  for _, model_name in pairs(model_list) do
    if string.find(stripped_model, model_name, 1, true) then
      model_list[player_model] = model_name

      break
    end
  end

  return player_manager.TranslatePlayerHands(model_list[player_model])
end

--- Draws the hands of the local player after the view model has been drawn.
-- @param _viewmodel [Entity]
-- @param weapon [Weapon]
function flux_player:PostDrawViewModel(_viewmodel, weapon)
  if weapon.UseHands or !weapon:IsScripted() then
    local hands_entity = self.Player:GetHands()

    if IsValid(hands_entity) then
      hands_entity:DrawModel()
    end
  end
end

--- Gives the player the default loadout of the player class, as the 'AdjustPlayerLoadout'
-- hook changes it, with `Player:give_loadout`. Server only.
function flux_player:Loadout()
  local loadout = table.Copy(self.loadout)

  --- Called on the server when a player gets their loadout after spawning, before their
  -- weapons are stripped and they are given the weapons of the loadout. Handlers add,
  -- remove or reorder the weapon classes of `loadout` in place and return nothing; the
  -- player selects the first one.
  -- @param actor [Player the player who has spawned]
  -- @param loadout [List<String> weapon classes, a copy of the default loadout of the player
  --   class]
  -- @realm [server]
  hook.Run('AdjustPlayerLoadout', self.Player, loadout)

  self.Player:give_loadout(loadout)
end

player_manager.RegisterClass('flux_player', flux_player, 'player_default')
