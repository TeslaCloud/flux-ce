-- Disable default Sandbox persistence.
hook.Remove('ShutDown', 'SavePersistenceOnShutdown')
hook.Remove('PersistenceSave', 'PersistenceSave')
hook.Remove('PersistenceLoad', 'PersistenceLoad')
hook.Remove('InitPostEntity', 'PersistenceInit')

local whitelisted_ents = {
  gmod_light                = true,
  gmod_lamp                 = true,
  prop_physics              = true,
  prop_physics_multiplayer  = true,
  prop_ragdoll              = true
}

--- Runs the PersistenceLoad hook once the map's entities have been created.
function StaticEnts:InitPostEntity()
  hook.Run('PersistenceLoad')
end

--- Runs the PersistenceSave hook when the server shuts down.
function StaticEnts:ShutDown()
  hook.Run('PersistenceSave')
end

--- Saves every persistent entity to the plugin data of the current schema and map, one
-- 'static/<class>' entry per entity class. Runs the PrePersistenceSave hook first.
function StaticEnts:PersistenceSave()
  hook.Run('PrePersistenceSave')

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
    Data.save_plugin('static/'..ent_class, v)
  end
end

--- Loads the saved static entities of every whitelisted class.
function StaticEnts:PersistenceLoad()
  for ent_class, v in pairs(whitelisted_ents) do
    self:load_class(ent_class)
  end
end

--- Makes the entity the player is looking at static, or removes its static status, and
-- notifies the player about the outcome. The entity's class has to be whitelisted and the
-- player needs the 'static' or 'unstatic' permission respectively.
-- @param actor [Player]
-- @param is_static [Boolean true to make the entity static, false to make it unstatic]
function StaticEnts:PlayerMakeStatic(actor, is_static)
  if (is_static and !actor:can('static')) or (!is_static and !actor:can('unstatic')) then
    actor:notify('error.no_permission')
    return
  end

  local trace = actor:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if !IsValid(entity) then
    actor:notify('error.not_valid_entity')
    return
  end

  if !whitelisted_ents[entity:GetClass()] then
    actor:notify('error.cannot_static_this')
    return
  end

  local ent_static = entity:GetPersistent()

  if is_static and ent_static then
    actor:notify('error.already_static')
    return
  elseif !is_static and !ent_static then
    actor:notify('error.not_static')
    return
  end

  entity:SetPersistent(is_static)

  actor:notify((is_static and 'notification.static.added') or 'notification.static.removed')
end

--- Runs the PersistenceSave hook whenever the framework saves its data.
function StaticEnts:SaveData()
  hook.Run('PersistenceSave')
end

--- Spawns the saved static entities of one class and marks them as persistent.
-- Does nothing if there is no usable save for that class. Serverside only.
-- @param ent_class [String entity class, e.g. 'prop_physics']
function StaticEnts:load_class(ent_class)
  local loaded = Data.load_plugin('static/'..ent_class, false)

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

--- Allows entities of a class to be made static and to be loaded from the saves.
-- Serverside only.
-- @param ent_class [String entity class]
function StaticEnts:whitelist_ent(ent_class)
  whitelisted_ents[ent_class] = true
end
