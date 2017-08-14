--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("hint", fl)

local stored = {}

function fl.hint:Add(id, text, color, bPlaySound, callback)
	table.insert(stored, {id = id, text = text, color = color, playSound = bPlaySound or false, callback = callback})
end

function fl.hint:DisplayRandom()
	local hint = table.Random(stored)

	if (hint.callback and hint.callback() != true) then return end
	if (hint.playSound) then surface.PlaySound("hl1/fvox/blip.wav") end

	fl.notification:Add(hint.text, 15, hint.color)
end

do
	fl.hint:Add("#Hint_Forums", "#Hint_ForumsText")
	fl.hint:Add("#Hint_Hints", "#Hint_HintsText")
	fl.hint:Add("#Hint_TAB", "#Hint_TABText")
	fl.hint:Add("#Hint_Inventory", "#Hint_InventoryText")
	fl.hint:Add("#Hint_Commands", "#Hint_CommandsText")
	fl.hint:Add("#Hint_Bugs", "#Hint_BugsText")
end