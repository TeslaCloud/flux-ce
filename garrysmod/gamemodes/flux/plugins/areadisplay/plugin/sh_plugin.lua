areas.RegisterType(
  'text',
  'Text Area',
  'An area that displays text when player enters it.',
  function(player, area, poly, has_entered, cur_pos, cur_time)
    if has_entered then
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
    --cable.send(player, 'flLoadTextAreas', areas.GetByType('text'))
  end

  function PLUGIN:InitPostEntity()
    --self:Load()
  end

  function PLUGIN:SaveData()
    --self:Save()
  end
else
  cable.receive('flLoadTextAreas', function(data)
    for k, v in pairs(data) do
      areas.register(k, v)
    end
  end)
end
