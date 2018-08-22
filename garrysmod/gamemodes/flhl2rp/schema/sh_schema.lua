--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]util.Include("cl_hooks.lua")

Schema.DefaultTheme = "hl2rp"

function Schema:IsCombineFaction(faction)
  return faction == "cca" or faction == "ota" or faction == "ca"
end

function Schema:PlayerIsCombine(player)
  return self:IsCombineFaction(player:GetFactionID())
end
