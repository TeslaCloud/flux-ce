--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("undo", rw)

local queue = {}
local buffer = {}

function rw.undo:Create(id, name)
	buffer = {
		uniqueID = id,
		name = name,
		player = nil,
		functions = {}
	}
end

function rw.undo:Add(callback, ...)
	table.insert(buffer.functions, {func = callback, args = {...})
end

function rw.undo:SetPlayer(player)
	buffer.player = player
end

function rw.undo:Finish()
	if (istable(buffer) and IsValid(buffer.player)) then
		queue[buffer.player] = queue[buffer.player] or {}

		table.insert(queue[buffer.player], buffer)
	end

	buffer = {}
end

function rw.undo:Do(obj)
	if (istable(obj) and istable(obj.functions)) then
		for k, v in ipairs(obj.functions) do
			Try("Undo", v.func, obj, unpack(v.args))
		end
	end
end

function rw.undo:DoPlayer(player)
	local count = (queue[player] and #queue[player]) or 0

	if (count > 0) then
		-- do the top of the queue
		self:Do(queue[player][count])
		table.remove(queue[player], count)
	end
end

function rw.undo:GetPlayer(player)
	return queue[player] or {}
end