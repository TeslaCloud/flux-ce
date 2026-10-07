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
  --- Currently does nothing; sending the text areas to the player is commented out.
  -- @param player [Player]
  function PLUGIN:PlayerInitialized(player)
    --Cable.send(player, 'fl_areas_text_load', Areas.get_by_type('text'))
  end

  --- Currently does nothing; loading of the saved areas is commented out.
  function PLUGIN:InitPostEntity()
    --self:load()
  end

  --- Currently does nothing; saving of the areas is commented out.
  function PLUGIN:SaveData()
    --self:save()
  end

  --- Currently does nothing; saving of the text areas is commented out.
  function PLUGIN:save()
    --Data.save_plugin('areas', Areas.get_by_type('text') or {})
  end

  --- Loads the areas saved in the 'areas' plugin data and registers each of them.
  -- Serverside only.
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
