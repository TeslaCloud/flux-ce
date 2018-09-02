-- Disable default Sandbox persistence.
hook.Remove("ShutDown", "SavePersistenceOnShutdown")
hook.Remove("PersistenceSave", "PersistenceSave")
hook.Remove("PersistenceLoad", "PersistenceLoad")
hook.Remove("InitPostEntity", "PersistenceInit")

local whitelistedEntities = {
  ["prop_physics"] = true,
  ["prop_physics_multiplayer"] = true,
  ["prop_ragdoll"] = true,
  ["gmod_light"] = true,
  ["gmod_lamp"] = true
}

function flStaticEnts:PlayerMakeStatic(player, bIsStatic)
  if ((bIsStatic and !player:can("static")) or (!bIsStatic and !player:can("unstatic"))) then
    fl.player:notify(player, L("Err_No_Permission", player:Name()))

    return
  end

  local trace = player:GetEyeTraceNoCursor()
  local entity = trace.Entity

  if (!IsValid(entity)) then
    fl.player:notify(player, t('err.not_valid_entity'))

    return
  end

  if (!whitelistedEntities[entity:GetClass()]) then
    fl.player:notify(player, t('err.cannot_static_this'))

    return
  end

  local isStatic = entity:GetPersistent()

  if (bIsStatic and isStatic) then
    fl.player:notify(player, t('err.already_static'))

    return
  elseif (!bIsStatic and !isStatic) then
    fl.player:notify(player, t('err.not_static'))

    return
  end

  entity:SetPersistent(bIsStatic)

  fl.player:notify(player, (bIsStatic and "static.added") or "static.removed")
end

function flStaticEnts:ShutDown()
  hook.run("PersistenceSave")
end

function flStaticEnts:PersistenceSave()
  local entities = {}

  for k, v in ipairs(ents.GetAll()) do
    if (v:GetPersistent()) then
      table.insert(entities, v)
    end
  end

  local toSave = duplicator.CopyEnts(entities)

  if (!istable(toSave)) then return end

  data.SavePlugin("static", toSave)
end

function flStaticEnts:PersistenceLoad()
  local loaded = data.LoadPlugin("static")

  if (!istable(loaded)) then return end
  if (!loaded.Entities) then return end
  if (!loaded.Constraints) then return end

  local entities, constraints = duplicator.Paste(nil, loaded.Entities, loaded.Constraints)

  -- Restore any custom data the static entities might have had.
  for k, v in pairs(entities) do
    local entData = loaded.Entities[k]

    if (entData) then
      table.safe_merge(v:GetTable(), entData)
    end
  end

  for k, v in pairs(entities) do
    v:SetPersistent(true)
  end
end

function flStaticEnts:InitPostEntity()
  hook.run("PersistenceLoad")
end
