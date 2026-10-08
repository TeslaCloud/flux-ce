--- Area Display registers the `text` area type, meant to show the name of an area to the
-- players who enter it.
-- Entering or leaving an area of that type runs the `PlayerEnteredTextArea` and
-- `PlayerLeftTextArea` hooks. The plugin is unfinished: the notice it shows on the HUD is
-- a placeholder text, and saving and networking of its areas are commented out.

Areas.register_type(
  'text',
  'Text Area',
  'An area that displays text when a player enters it.',
  Color(255, 0, 255),
  function(actor, area, has_entered, pos, cur_time)
    if has_entered then
      --- Called when a player enters an area of the `text` type. Runs on the server and on
      -- the client of that player.
      -- @param actor [Player The player who has entered the area]
      -- @param area [Map The area table]
      -- @param cur_time [Number CurTime() of the check]
      Plugin.call('PlayerEnteredTextArea', actor, area, cur_time)
    else
      --- Called when a player leaves an area of the `text` type. Runs on the server and on
      -- the client of that player.
      -- @param actor [Player The player who has left the area]
      -- @param area [Map The area table]
      -- @param cur_time [Number CurTime() of the check]
      Plugin.call('PlayerLeftTextArea', actor, area, cur_time)
    end
  end
)

require_relative 'cl_hooks'

if SERVER then
  --- Currently does nothing; sending the text areas to the player is commented out.
  -- @param actor [Player]
  function PLUGIN:PlayerInitialized(actor)
    -- Cable.send(actor, 'fl_areas_text_load', Areas.get_by_type('text'))
  end

  --- Currently does nothing; loading of the saved areas is commented out.
  function PLUGIN:InitPostEntity()
    -- self:load()
  end

  --- Currently does nothing; saving of the areas is commented out.
  function PLUGIN:SaveData()
    -- self:save()
  end

  --- Currently does nothing; saving of the text areas is commented out.
  function PLUGIN:save()
    -- Data.save_plugin('areas', Areas.get_by_type('text') or {})
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
