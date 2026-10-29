--- Server-side receiver of the Static Entities plugin: a player's request for a persistence
-- backup, see `StaticEnts:run_backup`.

Cable.receive('fl_persistence_backup', function(actor)
  StaticEnts:run_backup(actor)
end)
