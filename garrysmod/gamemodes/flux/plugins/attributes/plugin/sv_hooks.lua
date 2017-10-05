--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flAttributes:DatabaseConnected()
	fl.db:AddColumn("fl_characters", "attributes", "TEXT DEFAULT NULL")
end

function flAttributes:SaveCharaterData(player, saveData)
	saveData.attributes = util.TableToJSON(player:GetAttributeTable())
end

function flAttributes:RestoreCharacter(player, charID, data)
	local char = character.Get(player, charID)

	if (char) then
		char.attributes = util.JSONToTable(data.attributes)

		character.Save(player, charID)
	end
end

function flAttributes:PostCreateCharacter(player, charID, data)
	local char = character.Get(player, charID)

	if (char) then
		char.attributes = data.attributes

		character.Save(player, charID)
	end
end

function flAttributes:OnActiveCharacterSet(player, character)
	player:SetNetVar("Attributes", character.attributes or {})
end