--- Server side of the Areas API plugin: saves and loads the areas, sends them to players,
-- checks every second which players have entered or left an area, and makes a player who
-- disconnects leave the areas they are in.

--- Sends all stored areas to the player who has just initialized.
-- @param actor [Player]
function Area:PlayerInitialized(actor)
  Cable.send(actor, 'fl_areas_load', Areas.all())
end

--- Loads the saved areas from the plugin data storage.
function Area:LoadData()
  local loaded = Data.load_plugin('areas', {})

  Areas.set_stored(loaded)
end

--- Saves all stored areas to the plugin data storage.
function Area:SaveData()
  Areas.save()
end

--- Checks every player against the areas once a second.
-- @see [Areas.update_player]
function Area:OneSecond()
  local cur_time = CurTime()

  for _, actor in player.Iterator() do
    Areas.update_player(actor, cur_time)
  end
end

--- Makes a player who leaves the server leave every area they are inside of.
-- @param actor [Player]
function Area:PlayerDisconnected(actor)
  Areas.leave_all(actor)
end
