--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]FACTION.Name = "#Faction_Combine_Overwatch"
FACTION.Description = "Combine military soldiers."
FACTION.PhysDesc = "Wearing heavy overwatch armor."
FACTION.Color = Color(225, 115, 100)
FACTION.Material = "flux/hl2rp/factions/overwatch.png"
FACTION.HasName = false
FACTION.HasGender = false
FACTION.Whitelisted = true
FACTION.DefaultClass = "soldier"
FACTION.NameTemplate = "OW.{data:Squad}-{rank}.{callback:GenerateID}"
FACTION:SetData("Squad", "ECHO")
FACTION.Models.universal = {
  "models/combine_soldier.mdl"
}

FACTION:AddRank("OWS")
FACTION:AddRank("GUARD")
FACTION:AddRank("EOW")

FACTION:AddClass("soldier", "Overwatch Soldier", "Regular Overwatch soldier", FACTION.Color, function(player)
  return true
end)

FACTION:AddClass("guard", "Overwatch Guard", "Overwatch soldier that specializes at guarding important locations and people.", FACTION.Color, function(player)
  return player:IsRank("GUARD")
end)

FACTION:AddClass("elite_ow", "Elite Overwatch Unit", "Elite Overwatch soldier that serves directly under city administrator.", FACTION.Color, function(player)
  return player:IsRank("EOW")
end)

function FACTION:GenerateID(player)
  local id = player:GetCharacterData("UnitID", false)

  if (!id) then
    id = math.random(100, 999)

    player:SetCharacterData("UnitID", id)
  end

  return id
end
