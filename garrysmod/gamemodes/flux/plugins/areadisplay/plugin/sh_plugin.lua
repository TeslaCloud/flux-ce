areas.register_type(
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
  function PLUGIN:PlayerInitialized(player)
    --cable.send(player, 'fl_areas_text_load', areas.get_by_type('text'))
  end

  function PLUGIN:InitPostEntity()
    --self:load()
  end

  function PLUGIN:SaveData()
    --self:save()
  end

  function PLUGIN:save()
    --data.save_plugin('areas', areas.get_by_type('text') or {})
  end

  function PLUGIN:load()
    local loaded = data.load_plugin('areas', {})

    for k, v in pairs(loaded) do
      areas.register(k, v)
    end
  end
else
  cable.receive('fl_areas_text_load', function(data)
    for k, v in pairs(data) do
      areas.register(k, v)
    end
  end)
end
