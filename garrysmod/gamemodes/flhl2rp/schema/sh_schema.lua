util.include("cl_hooks.lua")

Schema.DefaultTheme = "hl2rp"

function Schema:IsCombineFaction(faction)
  return faction == "cca" or faction == "ota" or faction == "ca"
end

function Schema:PlayerIsCombine(player)
  return self:IsCombineFaction(player:GetFactionID())
end
