--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flCharacters:ClientIncludedSchema(player)
	character.Load(player)
end

function flCharacters:PostCharacterLoaded(player, character)
	netstream.Start(player, "PostCharacterLoaded", character.uniqueID)

	player:CheckInventory()

	for slot, ids in ipairs(player:GetInventory()) do
		for k, v in ipairs(ids) do
			item.NetworkItem(player, v)
		end
	end
end

function flCharacters:OnActiveCharacterSet(player, character)
	player:Spawn()
	player:SetModel(character.model or "models/humans/group01/male_02.mdl")

	hook.Run("PostCharacterLoaded", player, character)
end