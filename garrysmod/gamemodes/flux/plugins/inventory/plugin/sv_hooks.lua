--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flInventory:PostCharacterLoaded(player, character)
	player:CheckInventory()

	for slot, ids in ipairs(player:GetInventory()) do
		for k, v in ipairs(ids) do
			item.NetworkItem(player, v)
		end
	end
end