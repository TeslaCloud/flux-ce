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
	fl.hint:Add("Forums", "You can visit TeslaCloud forums to get support, download schemas\nand chat with fellow Flux users!")
	fl.hint:Add("Hints", "These hints can be disabled from clientside settings menu.\nNot in this build though.")
	fl.hint:Add("TAB", "Press 'Show Scoreboard' key (default: TAB) to open Flux's menu.")
	fl.hint:Add("Inventory", "Dran'n'Drop an item outside of inventory screen to drop it.")
	fl.hint:Add("Commands", "Start typing a command in chat to see a list of all available commands\nand their syntax help.")
	fl.hint:Add("Bugs", "Encountered a bug? Have an idea that we should totally add to Flux?\nVisit our forums at teslacloud.net and tell us about it!")
end