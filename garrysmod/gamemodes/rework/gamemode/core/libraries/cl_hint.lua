--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("hint", rw)

local stored = {}

function rw.hint:Add(id, text, color, bPlaySound, callback)
	table.insert(stored, {id = id, text = text, color = color, playSound = bPlaySound or false, callback = callback})
end

function rw.hint:DisplayRandom()
	local hint = table.Random(stored)

	if (hint.callback and hint.callback() != true) then return; end
	if (hint.playSound) then surface.PlaySound("hl1/fvox/blip.wav"); end

	rw.notification:Add(hint.text, 15, hint.color)
end

do
	rw.hint:Add("Forums", "You can visit TeslaCloud forums to get support, download schemas\nand chat with fellow Rework users!")
	rw.hint:Add("Hints", "These hints can be disabled from clientside settings menu.\nNot in this build though.")
	rw.hint:Add("TAB", "Press 'Show Scoreboard' key (default: TAB) to open Rework's menu.")
	rw.hint:Add("Inventory", "Dran'n'Drop an item outside of inventory screen to drop it.")
	rw.hint:Add("Commands", "Start typing a command in chat to see a list of all available commands\nand their syntax help.")
	rw.hint:Add("Bugs", "Encountered a bug? Have an idea that we should totally add to Rework?\nVisit our forums at teslacloud.net and tell us about it!")
end