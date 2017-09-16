--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flPrefixes")
PLUGIN:SetName("Prefixes")
PLUGIN:SetAuthor("AleXXX_007")
PLUGIN:SetDescription("Adds prefix adjusting to avoid troubles with certain commands.")

local stored = {}

function flPrefixes:AddPrefix(prefix, callback)
	table.insert(stored, {prefix = prefix, callback = callback})
end

function flPrefixes:ChatboxAdjustPrefix(str)
	for k, v in pairs(stored) do
		if (istable(v.prefix)) then
			for k1, v1 in pairs(v.prefix) do
				if (str:utf8lower():StartWith(v1)) then
					return false
				end
			end
		elseif (str:utf8lower():StartWith(v.prefix)) then
			return false
		end
	end
end

function flPrefixes:PlayerSay(player, text, bTeamChat)
	for k, v in pairs(stored) do
		if (istable(v.prefix)) then
			for k1, v1 in pairs(v.prefix) do
				if (text:utf8lower():StartWith(v1)) then
					local message = text:utf8sub(v1:utf8len() + 1)

					if (message != "") then
						v.callback(player, message, bTeamChat)
					end

					return ""
				end
			end
		elseif (text:utf8lower():StartWith(v.prefix)) then
			local message = text:utf8sub(v.prefix:utf8len() + 1)

			if (message != "") then
				v.callback(player, message, bTeamChat)
			end

			return ""
		end
	end
end