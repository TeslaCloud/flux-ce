--- Shared handlers of the CAMI hooks, registered as `Bolt`. As the provider, Bolt takes over
-- the usergroups and privileges that other addons register, drops the permissions of the
-- privileges they unregister and answers the access checks of the permissions it knows.
-- Deferring to another admin mod, Bolt leaves all of them to that admin mod. Bolt keeps the
-- roles of the usergroups that are unregistered, since a role cannot be removed.

local hooks = {}

--- Makes a usergroup that another admin mod registers a Bolt role, see
-- `Bolt:import_cami_usergroup`.
-- @param _self [Map the hook table]
-- @param usergroup [Map CAMI usergroup]
-- @param source [Any the admin mod that registered it]
hooks['CAMI.OnUsergroupRegistered'] = function(_self, usergroup, source)
  if Bolt:is_cami_provider() and source != 'Bolt' then
    Bolt:import_cami_usergroup(usergroup, source)
  end
end

--- Makes a privilege that another addon registers a Bolt permission, see
-- `Bolt:import_cami_privilege`.
-- @param _self [Map the hook table]
-- @param privilege [Map CAMI privilege]
hooks['CAMI.OnPrivilegeRegistered'] = function(_self, privilege)
  if Bolt:is_cami_provider() then
    Bolt:import_cami_privilege(privilege)
  end
end

--- Removes the permission of a privilege that another addon unregisters, see
-- `Bolt:remove_cami_privilege`.
-- @param _self [Map the hook table]
-- @param privilege [Map CAMI privilege]
hooks['CAMI.OnPrivilegeUnregistered'] = function(_self, privilege)
  if Bolt:is_cami_provider() and istable(privilege) then
    Bolt:remove_cami_privilege(privilege.Name)
  end
end

--- Answers whether a player has a privilege that is a Bolt permission, with `Player:can`. A
-- check against another player also needs the immunity to act on them
-- (`Bolt:check_immunity`), unless the check asks to ignore it with `IgnoreImmunity`, and a
-- privilege with a `HasAccess` function also needs that function to agree, as with CAMI's
-- own answer. Other privileges, and every privilege while Bolt defers to another admin mod,
-- are left to the other handlers and to CAMI.
-- @param _self [Map the hook table]
-- @param actor [Player the player whose access is checked]
-- @param privilege_name [String privilege name]
-- @param callback [Function called with the answer and 'Bolt']
-- @param target [Player the player the privilege is used on, or nil]
-- @param extra [Map extra information of the check, or nil]
-- @return [Boolean true when Bolt has answered, nothing otherwise]
hooks['CAMI.PlayerHasAccess'] = function(_self, actor, privilege_name, callback, target, extra)
  if Bolt:uses_external_admin() or !isstring(privilege_name) or !Bolt:get_permission(privilege_name) then return end
  if !IsValid(actor) or !actor:IsPlayer() then return end

  local allowed = actor:can(privilege_name) == true

  if allowed and IsValid(target) and target:IsPlayer() and !extra?.IgnoreImmunity then
    allowed = Bolt:check_immunity(actor, target)
  end

  local privilege = CAMI.GetPrivilege(privilege_name)

  if allowed and privilege and isfunction(privilege.HasAccess) then
    allowed = privilege:HasAccess(actor, target) == true
  end

  callback(allowed, 'Bolt')

  return true
end

Plugin.add_hooks('Bolt', hooks)
