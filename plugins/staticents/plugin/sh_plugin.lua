--- Static Entities lets staff make entities persistent, so that they are saved with the map
-- and spawned again when it loads.
-- Entities are made static or unstatic with the `static add` and `static remove` commands or
-- with the Static Add/Remove tool, which all go through the `PlayerMakeStatic` hook. Only
-- whitelisted classes can be made static: props, ragdolls, lights and lamps by default, and
-- whatever plugins add with `StaticEnts:whitelist_ent`. The plugin turns Sandbox's own
-- persistence off and saves and loads through the `PersistenceSave` and `PersistenceLoad`
-- hooks instead. The `fl_persistence_backup` console command writes a copy of all persistent
-- entities to the data folder.

PLUGIN:set_global('StaticEnts')

require_relative 'sv_hooks'

--- Registers the 'static_tool' permission.
function StaticEnts:RegisterPermissions()
  Bolt:register_permission(
    'static_tool',
    'Static (tool)',
    'Grants access to make entities static / unstatic.',
    'permission.categories.level_design'
  )
end

if CLIENT then
  concommand.Add('fl_persistence_backup', function(actor)
    if actor:IsSuperAdmin() then
      print('Requesting the server to make a backup...')

      Cable.send('flux_persistence_backup', true)
    end
  end)

  Cable.receive('flux_persistence_backup', function(status)
    if status then
      print('  -> success!')
    else
      print('  -> error!')
    end
  end)
else
  local function _run_backup(actor)
    local is_player = IsValid(actor)

    if is_player and !actor:IsSuperAdmin() then return end

    local pn = is_player and actor:Name() or 'Console'
    local sid = is_player and actor:SteamID() or 'N/A'

    print('Running persistence backup, as requested by '..pn..' ('..sid..')')

    if !file.Exists('flux', 'DATA') then
      file.CreateDir('flux')
    end

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

    local ts = to_timestamp(os.time())
    local target_dir = 'flux/'..ts

    if !file.Exists(target_dir, 'DATA') then
      file.CreateDir(target_dir)
    end

    local status = true

    for ent_class, save_data in pairs(to_save) do
      if !istable(save_data) then
        print('  -> error: saveable data is not a table! ('..ent_class..')')
        status = false
        break
      end

      print('  -> '..ent_class)
      file.Write(target_dir..'/'..ent_class..'.txt', util.TableToJSON(save_data))
    end

    print('  -> '..(status and 'done!' or 'error!'))

    if is_player then
      Cable.send(actor, 'flux_persistence_backup', status)
    end
  end

  Cable.receive('flux_persistence_backup', _run_backup)
  concommand.Add('fl_persistence_backup', _run_backup)
end
