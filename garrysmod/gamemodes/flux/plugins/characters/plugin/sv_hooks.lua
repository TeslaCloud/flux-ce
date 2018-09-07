function flCharacters:PlayerInitialSpawn(player)
  player:SetNoDraw(true)
  player:SetNotSolid(true)
  player:Lock()

  timer.Simple(1, function()
    if IsValid(player) then
      player:KillSilent()
      player:StripAmmo()
    end
  end)
end

function flCharacters:PlayerRestored(player)
  character.Load(player)
end

function flCharacters:PlayerInitialized(player)
  character.SendToClient(player)
end

function flCharacters:PostCharacterLoaded(player, character)
  hook.runClient(player, "PostCharacterLoaded", character.id)
end

function flCharacters:OnActiveCharacterSet(player, character)
  player:Spawn()
  player:SetModel(character.model or "models/humans/group01/male_02.mdl")

  player:StripAmmo()

  if istable(character.ammo) then
    for k, v in pairs(character.ammo) do
      player:SetAmmo(v, k)
    end

    character.ammo = nil
  end

  hook.run("PostCharacterLoaded", player, character)
end

function flCharacters:OnCharacterChange(player, oldChar, newCharID)
  player:SaveCharacter()
  character.Load(player)
end

function flCharacters:PlayerDisconnected(player)
  player:SaveCharacter()
end

function flCharacters:PlayerDeath(player, inflictor, attacker)
  player:SaveCharacter()
end
