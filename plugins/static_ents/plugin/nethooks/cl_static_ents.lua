--- Client-side receiver of the Static Entities plugin: the result of the persistence backup
-- that the local player has asked for.

Cable.receive('fl_persistence_backup', function(status)
  if status then
    print('  -> success!')
  else
    print('  -> error!')
  end
end)
