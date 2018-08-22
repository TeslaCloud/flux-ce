--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]PLUGIN:SetAlias("flPrefixes")
PLUGIN:SetName("Prefixes")
PLUGIN:SetAuthor("AleXXX_007")
PLUGIN:SetDescription("Adds prefix adjusting to avoid troubles with certain commands.")

local stored = {}

function flPrefixes:AddPrefix(prefix, callback)
  table.insert(stored, {prefix = prefix, callback = callback})
end

function flPrefixes:StringIsCommand(str)
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
  for k, v in ipairs(stored) do
    if (istable(v.prefix)) then
      for k2, v2 in ipairs(v.prefix) do
        if (text:utf8lower():StartWith(v2)) then
          local message = text:utf8sub(v2:utf8len() + 1)

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
