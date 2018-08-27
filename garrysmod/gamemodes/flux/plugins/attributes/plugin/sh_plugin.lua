PLUGIN:set_alias("flAttributes")

util.include("sv_hooks.lua")

function flAttributes:OnPluginLoaded()
  local dir = self:get_folder().."/plugin/"

  attributes.register_type("skills", "SKILL", dir.."skills/")
  attributes.register_type("stats", "STAT", dir.."stats/")
  attributes.register_type("perks", "PERK", dir.."perks/")
end

function flAttributes:PluginIncludeFolder(extra, folder)
  for k, v in pairs(attributes.types) do
    if extra == k then
      attributes.include_type(k, v, folder.."/"..k.."/")

      return true
    end
  end
end
