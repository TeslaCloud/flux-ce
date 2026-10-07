PLUGIN:set_global('StaticEnts')

require_relative 'sv_hooks'

--- Registers the 'static_tool' permission.
function StaticEnts:RegisterPermissions()
  Bolt:register_permission('static_tool', 'Static (tool)', 'Grants access to make entities static / unstatic.', 'permission.categories.level_design', 'assistant')
end

--- @deprecation [Remove in 1.0_b]
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
--- @deprecation [Remove in 1.0_b]
else
  local function _run_backup(actor)
    if IsValid(actor) and !actor:IsSuperAdmin() then return end

    local pn = IsValid(actor) and actor:Name() or 'Console'
    local sid = IsValid(actor) and actor:SteamID() or 'N/A'

    print('Running persistence backup, as requested by '..pn..' ('..sid..')')

    if !file.Exists('flux', 'DATA') then
      file.CreateDir('flux')
    end

    local entities = {}

    for k, v in ipairs(ents.GetAll()) do
      if v:GetPersistent() then
        local ent_class = v:GetClass()
        entities[ent_class] = entities[ent_class] or {}
        table.insert(entities[ent_class], v)
      end
    end

    local to_save = {}

    for ent_class, entities in pairs(entities) do
      to_save[ent_class] = duplicator.CopyEnts(entities)
    end

    local ts = to_timestamp(os.time())
    local target_dir = 'flux/'..ts

    if !file.Exists(target_dir, 'DATA') then
      file.CreateDir(target_dir)
    end

    local status = true

    for ent_class, v in pairs(to_save) do
      if !istable(v) then
        print('  -> error: saveable data is not a table! ('..ent_class..')')
        status = false
        break
      end
      print('  -> '..ent_class)
      file.Write(target_dir..'/'..ent_class..'.txt', util.TableToJSON(v))
    end

    print('  -> '..(status and 'done!' or 'error!'))

    if IsValid(actor) then
      Cable.send(actor, 'flux_persistence_backup', status)
    end
  end

  Cable.receive('flux_persistence_backup', _run_backup)
  concommand.Add('fl_persistence_backup', _run_backup)
end
