FACTION.Name = "#Faction_Civil_Authority"
FACTION.Description = "Combine police forces."
FACTION.PhysDesc = "Wearing shiny metropolice unit uniform with brand new stunstick on his belt."
FACTION.Color = Color(135, 140, 225)
FACTION.Material = "flux/hl2rp/factions/cca.png"
FACTION.HasName = false
FACTION.HasGender = false
FACTION.Whitelisted = true
FACTION.DefaultClass = "recruit"
FACTION.NameTemplate = "CCA.{rank}-{data:Squad}.{callback:GenerateID}"
FACTION:SetData("Squad", "UNION")
FACTION.Models.universal = {
  "models/police.mdl"
}

FACTION:AddRank("RCT")
FACTION:AddRank("04")
FACTION:AddRank("03")
FACTION:AddRank("02")
FACTION:AddRank("01")
FACTION:AddRank("SqO") -- Squad Officer
FACTION:AddRank("DC") -- Division Commander
FACTION:AddRank("CmD") -- Commander

FACTION:AddClass("recruit", "Metropolice Recruit", "Metropolice Unit that is yet to pass their basic training.", FACTION.Color, function(player)
  return true
end)

FACTION:AddClass("unit", "Metropolice Unit", "A regular Metropolice Force unit.", FACTION.Color, function(player)
  return player:IsRank("04")
end)

FACTION:AddClass("elite_mpf", "Elite Metropolice", "Metropolice high command.", FACTION.Color, function(player)
  return player:IsRank("SqO")
end)

function FACTION:GenerateID(player)
  local id = player:GetCharacterData("UnitID", false)

  if (!id) then
    id = math.random(100, 999)

    player:SetCharacterData("UnitID", id)
  end

  return id
end
