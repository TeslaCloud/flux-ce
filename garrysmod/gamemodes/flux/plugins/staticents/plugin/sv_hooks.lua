-- Disable default Sandbox persistence.
hook.Remove("ShutDown", "SavePersistenceOnShutdown")
hook.Remove("PersistenceSave", "PersistenceSave")
hook.Remove("PersistenceLoad", "PersistenceLoad")
hook.Remove("InitPostEntity", "PersistenceInit")

local whitelisted_ents = {
  gmod_light                = true,
  gmod_lamp                 = true,
  prop_physics              = true,
  prop_physics_multiplayer  = true,
  prop_ragdoll              = true
}

function flStaticEnts:whitelist_ent(ent_class)
  whitelisted_ents[ent_class] = true
end

function flStaticEnts:PlayerMakeStatic(player, is_static)
  if (is_static and !player:can("static")) or (!is_static and !player:can("unstatic")) then
    fl.player:notify(player, 'err.no_permission', player:Name())
    return
  end

  local trace = player:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if !IsValid(entity) then
    fl.player:notify(player, 'err.not_valid_entity')
    return
  end

  if !whitelisted_ents[entity:GetClass()] then
    fl.player:notify(player, 'err.cannot_static_this')
    return
  end

  local ent_static = entity:GetPersistent()

  if is_static and ent_static then
    fl.player:notify(player, 'err.already_static')
    return
  elseif !is_static and !ent_static then
    fl.player:notify(player, 'err.not_static')
    return
  end

  entity:SetPersistent(is_static)

  fl.player:notify(player, (is_static and 'static.added') or 'static.removed')
end

function flStaticEnts:SaveData()
  hook.run("PersistenceSave")
end

function flStaticEnts:ShutDown()
  hook.run("PersistenceSave")
end

function flStaticEnts:PersistenceSave()
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

  for ent_class, v in pairs(to_save) do
    if !istable(v) then continue end
    data.SavePlugin('static/'..ent_class, v)
  end
end

function flStaticEnts:load_class(ent_class)
  local loaded = data.LoadPlugin('static/'..ent_class, false)

  if !istable(loaded) then return end
  if !loaded.Entities then return end
  if !loaded.Constraints then return end

  local entities, constraints = duplicator.Paste(nil, loaded.Entities, loaded.Constraints)

  -- Restore any custom data the static entities might have had.
  for k, v in pairs(entities) do
    local ent_data = loaded.Entities[k]

    if ent_data then
      table.safe_merge(v:GetTable(), ent_data)
    end
  end

  for k, v in pairs(entities) do
    v:SetPersistent(true)
  end
end

function flStaticEnts:PersistenceLoad()
  for ent_class, v in pairs(whitelisted_ents) do
    self:load_class(ent_class)
  end
end

function flStaticEnts:InitPostEntity()
  hook.run('PersistenceLoad')
end
