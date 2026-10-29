--- Client side of the Static Entities plugin: the console command with which a player asks
-- the server for a persistence backup.

concommand.Add('fl_persistence_backup', function(actor)
  if actor:can('static') then
    print('Requesting the server to make a backup...')

    Cable.send('fl_persistence_backup', true)
  end
end)
