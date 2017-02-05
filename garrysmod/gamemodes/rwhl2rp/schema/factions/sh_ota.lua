--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

FACTION.Name = "Overwatch Transhuman Arm"
FACTION.Description = "Combine military soldiers."
FACTION.PhysDesc = "Wearing heavy overwatch armor."
FACTION.Color = Color(225, 185, 135)
FACTION.Material = "rework/hl2rp/factions/ota.png"
FACTION.HasName = false
FACTION.Whitelisted = true
FACTION.DefaultClass = "soldier"
FACTION.NameTemplate = "OTA.{data:Squad}-{rank}.{callback:GenerateID}"
FACTION:SetData("Squad", "ECHO")
FACTION.Models.universal = {
	"models/police.mdl"
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

FACTION:AddClass("elite_ota", "Elite Overwatch Unit", "Elite Overwatch soldier that serves directly under city administrator.", FACTION.Color, function(player)
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