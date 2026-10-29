--- Server side of the Static Entities plugin: the persistence backup and its console command.

const backup_interval = 30

--- Writes a copy of all persistent entities to the plugin data of the current schema and map,
-- under 'static_backups/<timestamp>', and tells the player who has asked for it whether it
-- worked. A player needs the 'static' permission and may run it once every 30 seconds; the
-- server console always may.
-- @param actor [Player the player who has asked for the backup, NULL for the server console]
function StaticEnts:run_backup(actor)
  local is_player = IsValid(actor)

  if is_player then
    if !actor:can('static') then return end

    local cur_time = CurTime()

    if (actor.fl_next_backup or 0) > cur_time then return end

    actor.fl_next_backup = cur_time + backup_interval
  end

  local pn = is_player and actor:Name() or 'Console'
  local sid = is_player and actor:SteamID() or 'N/A'

  print('Running persistence backup, as requested by '..pn..' ('..sid..')')

  local entities = {}

  for _, ent in ents.Iterator() do
    if ent:GetPersistent() then
      local ent_class = ent:GetClass()
      entities[ent_class] = entities[ent_class] or {}
      table.insert(entities[ent_class], ent)
    end
  end

  local to_save = {}

  for ent_class, class_entities in pairs(entities) do
    to_save[ent_class] = duplicator.CopyEnts(class_entities)
  end

  local target_dir = 'static_backups/'..to_timestamp(os.time())
  local status = true

  for ent_class, save_data in pairs(to_save) do
    if !istable(save_data) then
      print('  -> error: saveable data is not a table! ('..ent_class..')')
      status = false
      break
    end

    print('  -> '..ent_class)
    Data.save_plugin(target_dir..'/'..ent_class, save_data)
  end

  print('  -> '..(status ? 'done!' : 'error!'))

  if is_player then
    Cable.send(actor, 'fl_persistence_backup', status)
  end
end

concommand.Add('fl_persistence_backup', function(actor)
  StaticEnts:run_backup(actor)
end)
