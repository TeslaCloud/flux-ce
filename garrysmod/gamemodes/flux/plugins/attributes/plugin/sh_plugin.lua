PLUGIN:set_alias("flAttributes")

util.include("sv_hooks.lua")

function flAttributes:OnPluginLoaded()
  local dir = self:get_folder().."/plugin/"

  attributes.RegisterType("skills", "SKILL", dir.."skills/")
  attributes.RegisterType("stats", "STAT", dir.."stats/")
  attributes.RegisterType("perks", "PERK", dir.."perks/")
end

function flAttributes:PluginIncludeFolder(extra, folder)
  for k, v in pairs(attributes.types) do
    if (extra == k) then
      attributes.IncludeType(k, v, folder.."/"..k.."/")

      return true
    end
  end
end
