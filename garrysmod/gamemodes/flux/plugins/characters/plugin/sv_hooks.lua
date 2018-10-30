function Characters:PostPlayerSpawn(player)
  if !player:GetCharacter() then
    player:SetNoDraw(true)
    player:SetNotSolid(true)
    player:Lock()

    timer.Simple(0, function()
      if IsValid(player) then
        player:KillSilent()
        player:StripAmmo()
      end
    end)
  end
end

function Characters:PlayerRestored(player)
  hook.run('PostRestoreCharacters', player)
end

function Characters:PlayerInitialized(player)
  character.SendToClient(player)
end

function Characters:PostCharacterLoaded(player, character)
  hook.run_client(player, 'PostCharacterLoaded', character.id)
end

function Characters:OnActiveCharacterSet(player, character)
  player:Spawn()
  player:SetModel(character.model or 'models/humans/group01/male_02.mdl')
  player:SetSkin(character.skin or 1)
  player:SetHealth(character.health or player:GetMaxHealth())
  player:StripAmmo()
  player:ScreenFade(SCREENFADE.IN, Color('white'), .5, .5)

  if istable(character.ammo) then
    for k, v in pairs(character.ammo) do
      player:SetAmmo(v, k)
    end
  end

  hook.run('PostCharacterLoaded', player, character)
end

function Characters:OnCharacterChange(player, oldChar, newCharID)
  player:SaveCharacter()
end

function Characters:PlayerDisconnected(player)
  player:SaveCharacter()
end

function Characters:PlayerDeath(player, inflictor, attacker)
  player:SaveCharacter()
end
