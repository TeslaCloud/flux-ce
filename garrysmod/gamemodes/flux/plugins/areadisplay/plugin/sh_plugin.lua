Areas.register_type(
  'text',
  'Text Area',
  'An area that displays text when player enters it.',
  function(player, area, poly, has_entered, cur_pos, cur_time)
    if has_entered then
      Plugin.call('PlayerEnteredTextArea', player, area, cur_time)
    else
      Plugin.call('PlayerLeftTextArea', player, area, cur_time)
    end
  end
)

require_relative 'cl_hooks'

if SERVER then
  function PLUGIN:PlayerInitialized(player)
    --Cable.send(player, 'fl_areas_text_load', Areas.get_by_type('text'))
  end

  function PLUGIN:InitPostEntity()
    --self:load()
  end

  function PLUGIN:SaveData()
    --self:save()
  end

  function PLUGIN:save()
    --Data.save_plugin('areas', Areas.get_by_type('text') or {})
  end

  function PLUGIN:load()
    local loaded = Data.load_plugin('areas', {})

    for k, v in pairs(loaded) do
      Areas.register(k, v)
    end
  end
else
  Cable.receive('fl_areas_text_load', function(data)
    for k, v in pairs(data) do
      Areas.register(k, v)
    end
  end)
end
