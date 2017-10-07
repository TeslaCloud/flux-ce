--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flAttributes:DatabaseConnected()
	fl.db:AddColumn("fl_characters", "attributes", "TEXT DEFAULT NULL")
end

function flAttributes:SaveCharaterData(player, saveData)
	saveData.attributes = util.TableToJSON(player:GetAttributes())
end

function flAttributes:RestoreCharacter(player, charID, data)
	local char = character.Get(player, charID)

	if (char) then
		if (isstring(data.attributes)) then
			char.attributes = util.JSONToTable(data.attributes)
		else
			char.attributes = {}
		end

		character.Save(player, charID)
	end
end

function flAttributes:PostCreateCharacter(player, charID, data)
	local char = character.Get(player, charID)

	if (char) then
		local attsTable = character.attributes

		for k, v in pairs(attributes.GetAll()) do
			local attribute = attributes.FindByID(v)

			attsTable[v] = {}
			attsTable[v].value = data.attributes[v]

			if (attribute.Multipliable) then
				attsTable[v].multiplier = 1
				attsTable[v].multiplierExpires = 0
			end

			if (attribute.Boostable) then
				attsTable[v].boost = 0
				attsTable[v].boostExpires = 1
			end
		end

		char.attributes = attsTable

		character.Save(player, charID)
	end
end

function flAttributes:OnActiveCharacterSet(player, character)
	player:SetNetVar("Attributes", character.attributes)
end