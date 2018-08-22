--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]areas.RegisterType(
  "text",
  "Text Area",
  "An area that displays text when player enters it.",
  function(player, area, poly, bHasEntered, curPos, curTime)
    if (bHasEntered) then
      plugin.call("PlayerEnteredTextArea", player, area, curTime)
    else
      plugin.call("PlayerLeftTextArea", player, area, curTime)
    end
  end
)

util.Include("cl_hooks.lua")

if SERVER then
  function PLUGIN:Save()
    --data.SavePlugin("areas", areas.GetByType("text") or {})
  end

  function PLUGIN:Load()
    local loaded = data.LoadPlugin("areas", {})

    for k, v in pairs(loaded) do
      areas.Register(k, v)
    end
  end

  function PLUGIN:PlayerInitialized(player)
    --netstream.Start(player, "flLoadTextAreas", areas.GetByType("text"))
  end

  function PLUGIN:InitPostEntity()
    --self:Load()
  end

  function PLUGIN:SaveData()
    --self:Save()
  end
else
  netstream.Hook("flLoadTextAreas", function(data)
    for k, v in pairs(data) do
      areas.Register(k, v)
    end
  end)
end
