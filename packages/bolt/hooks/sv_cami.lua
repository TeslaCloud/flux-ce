--- Server-side handlers of the CAMI hooks, registered as `Bolt`: applying the mode of
-- `bolt_external_admin` once the gamemode has initialized, taking over the usergroup changes
-- that other admin mods signal and answering the access checks of SteamIDs. All but the
-- first only apply while Bolt is the provider.

local hooks = {}

--- Applies the mode of `bolt_external_admin` with `Bolt:setup_cami`, once the configs of
-- the server, the schema and the data file are loaded.
function hooks:PostInitialize()
  Bolt:setup_cami()
end

--- Gives a player the role that another admin mod has signaled as their usergroup, if the
-- usergroup is a Bolt role (see `Bolt:role_for_cami_group`, so that 'superadmin' gives
-- `admin`), without signaling it back. A usergroup that the player has already, see
-- `Player:GetUserGroup`, is left as it is.
-- @param _self [Map the hook table]
-- @param target [Player the player whose usergroup has changed]
-- @param _old [String the usergroup they had]
-- @param new [String the usergroup they have]
-- @param source [Any the admin mod that changed it]
hooks['CAMI.PlayerUsergroupChanged'] = function(_self, target, _old, new, source)
  if !Bolt:is_cami_provider() or source == 'Bolt' or !IsValid(target) or !target:IsPlayer() then return end
  if new == target:GetUserGroup() then return end

  local role_id = Bolt:role_for_cami_group(new)

  if role_id and target:get_role() != role_id then
    target:set_role_id(role_id, true)
  end
end

--- Changes the stored role of a SteamID that has joined before to the one that another admin
-- mod has signaled as its usergroup, if the usergroup is a Bolt role (see
-- `Bolt:role_for_cami_group`), without signaling it back. A player with that SteamID who is
-- on the server gets the role right away.
-- @param _self [Map the hook table]
-- @param steam_id [String the SteamID whose usergroup has changed]
-- @param _old [String the usergroup it had]
-- @param new [String the usergroup it has]
-- @param source [Any the admin mod that changed it]
hooks['CAMI.SteamIDUsergroupChanged'] = function(_self, steam_id, _old, new, source)
  if !Bolt:is_cami_provider() or source == 'Bolt' or !isstring(steam_id) then return end

  steam_id = player.normalize_steam_id(steam_id)

  local role_id = player.is_steam_id(steam_id) and Bolt:role_for_cami_group(new)

  if !role_id then return end

  local online = player.find(steam_id)

  if IsValid(online) then
    online:set_role_id(role_id, true)
  else
    Bolt:set_stored_role(steam_id, role_id, nil, nil, true)
  end
end

--- Answers whether the owner of a SteamID has a privilege that is a Bolt permission: a root
-- SteamID has every one, a player on the server is asked with `Player:can`, and anybody else
-- is answered from the role stored for them, which is `user` for a SteamID that has never
-- joined. The stored role is looked up in the database, so the callback may run later.
-- @param _self [Map the hook table]
-- @param steam_id [String the SteamID whose access is checked]
-- @param privilege_name [String privilege name]
-- @param callback [Function called with the answer and 'Bolt']
-- @param _target_steam_id [String the SteamID the privilege is used on, or nil]
-- @param _extra [Map extra information of the check]
-- @return [Boolean true when Bolt answers, nothing otherwise]
hooks['CAMI.SteamIDHasAccess'] = function(_self, steam_id, privilege_name, callback, _target_steam_id, _extra)
  if !Bolt:is_cami_provider() or !isstring(privilege_name) or !Bolt:get_permission(privilege_name) then return end
  if !isstring(steam_id) then return end

  steam_id = player.normalize_steam_id(steam_id)

  if !player.is_steam_id(steam_id) then return end

  if Bolt:is_root_steam_id(steam_id) then
    callback(true, 'Bolt')

    return true
  end

  local online = player.find(steam_id)

  if IsValid(online) then
    callback(online:can(privilege_name) == true, 'Bolt')

    return true
  end

  Bolt:find_user(steam_id, function(user)
    callback(Bolt:role_allows(Bolt:find_group(user and user.role or 'user'), privilege_name), 'Bolt')
  end)

  return true
end

Plugin.add_hooks('Bolt', hooks)
