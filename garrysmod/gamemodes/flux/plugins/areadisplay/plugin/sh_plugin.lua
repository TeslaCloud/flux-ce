areas.RegisterType(
  'text',
  'Text Area',
  'An area that displays text when player enters it.',
  function(player, area, poly, bHasEntered, curPos, cur_time)
    if bHasEntered then
      plugin.call('PlayerEnteredTextArea', player, area, cur_time)
    else
      plugin.call('PlayerLeftTextArea', player, area, cur_time)
    end
  end
)

util.include('cl_hooks.lua')

if SERVER then
  function PLUGIN:Save()
    --data.save_plugin('areas', areas.GetByType('text') or {})
  end

  function PLUGIN:Load()
    local loaded = data.load_plugin('areas', {})

    for k, v in pairs(loaded) do
      areas.register(k, v)
    end
  end

  function PLUGIN:PlayerInitialized(player)
    --netstream.Start(player, 'flLoadTextAreas', areas.GetByType('text'))
  end

  function PLUGIN:InitPostEntity()
    --self:Load()
  end

  function PLUGIN:SaveData()
    --self:Save()
  end
else
  netstream.Hook('flLoadTextAreas', function(data)
    for k, v in pairs(data) do
      areas.register(k, v)
    end
  end)
end
