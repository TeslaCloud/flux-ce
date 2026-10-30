--- Bolt's side of CAMI, the interface through which admin mods and addons share usergroups and
-- privileges. The static `bolt_external_admin` config picks one of two modes, which
-- `Bolt:setup_cami` applies once the config is known: on the server after the gamemode has
-- initialized, on the client once the config has arrived. Bolt's roles are CAMI usergroups in
-- both modes, so that the role it gives a player is a usergroup that every admin mod knows.
--
-- As the provider (`bolt_external_admin` off), Bolt is the admin mod of the server. The
-- usergroups and privileges of other addons become Bolt roles and permissions, and Bolt
-- answers the access checks of CAMI for the permissions it knows. Bolt does not register its
-- own permissions as privileges.
--
-- Deferring (`bolt_external_admin` on), another admin mod owns the usergroups and privileges.
-- Bolt registers every permission as a privilege and asks CAMI in place of the role, after
-- root access and the permissions set on the player and their character, and the engine's
-- usergroup methods are left to that admin mod.
--
-- In both modes Bolt tells CAMI when it changes the role of a player, see `Bolt:set_role` and
-- `Bolt:set_stored_role`.

--- The usergroups that CAMI defines itself, which Bolt never registers.
local engine_groups = { user = true, admin = true, superadmin = true }

--- The Bolt role that each usergroup of CAMI stands for, by usergroup.
local engine_roles = { user = 'user', admin = 'assistant', superadmin = 'gamemaster' }

--- The usergroup of CAMI that Bolt's roles for 'admin' and 'superadmin' inherit from, by role.
local engine_parents = { assistant = 'admin', gamemaster = 'superadmin' }

--- The usergroup of CAMI that each of Bolt's default roles stands for, lowest first.
local role_access = {
  { 'user', 'user' },
  { 'assistant', 'admin' },
  { 'gamemaster', 'superadmin' },
  { 'admin', 'superadmin' }
}

local imported_privileges = Bolt.cami_privileges or {}
local registered_privileges = Bolt.cami_registered or {}
Bolt.cami_privileges = imported_privileges
Bolt.cami_registered = registered_privileges

local importing = {}
local cami_answer

local function store_cami_answer(allowed)
  cami_answer = allowed
end

--- Returns the mode that the `bolt_external_admin` config picks.
-- @return [String 'external' when it is on, 'provider' otherwise]
function Bolt:get_cami_mode()
  return Config.get('bolt_external_admin') == true ? 'external' : 'provider'
end

--- Checks whether Bolt defers to another admin mod, which `bolt_external_admin` decides once
-- `Bolt:setup_cami` has run. Bolt acts as the provider before that.
-- @return [Boolean]
function Bolt:uses_external_admin()
  return self.cami_mode == 'external'
end

--- Checks whether Bolt is the admin mod that CAMI hears from, which is the case once
-- `Bolt:setup_cami` has run with `bolt_external_admin` off.
-- @return [Boolean]
function Bolt:is_cami_provider()
  return self.cami_mode == 'provider'
end

--- Returns the Bolt role that a usergroup of CAMI stands for: `user` for 'user', `assistant`
-- for 'admin' and `gamemaster` for 'superadmin', or the role of the same ID otherwise.
-- @param group [String usergroup name]
-- @return [String role ID, nil if the usergroup is no Bolt role]
function Bolt:role_for_cami_group(group)
  local role_id = engine_roles[group] or group

  return self:find_group(role_id) and role_id or nil
end

--- Returns the Bolt role that stands for a usergroup. As the provider that is the role of
-- the same ID. Deferring to another admin mod, the usergroups of CAMI stand for the roles of
-- `Bolt:role_for_cami_group`, and any other usergroup for the role that the usergroup it
-- inherits from at the root stands for, so that 'user', 'admin' and 'superadmin' rank as
-- `user`, `assistant` and `gamemaster`.
-- @param group [String usergroup name]
-- @return [Role the role, or nil if no role stands for the usergroup]
function Bolt:get_group_role(group)
  if !self:uses_external_admin() then
    return self:find_group(group)
  end

  return self:find_group(self:role_for_cami_group(group) or self:role_for_cami_group(CAMI.InheritanceRoot(group)))
end

--- Checks whether a role allows an action on anything, for when there is no player to ask.
-- A permission with a callback counts as allowed, since there is nobody to call it for.
-- @param role [Role the role, or nil]
-- @param action [String permission ID]
-- @return [Boolean]
function Bolt:role_allows(role, action)
  if !role then return false end
  if role.can_anything then return true end

  local entry = role.permissions?.anything?.[action]

  return entry != nil and entry.allowed == true
end

--- Registers a role as a usergroup of CAMI. `assistant` inherits from 'admin' and
-- `gamemaster` from 'superadmin', the usergroups they stand for, and every other role from
-- its base role or from 'user'. Runs in both modes. Does nothing for the usergroups that CAMI
-- defines itself and for the roles that come from another admin mod's usergroups, and leaves a
-- usergroup of the same name that another admin mod has registered as it is.
-- @param role [Role]
function Bolt:register_cami_usergroup(role)
  local role_id = role.id or role.role_id

  if engine_groups[role_id] or role.cami_source then return end

  local usergroup = CAMI.GetUsergroup(role_id)

  if usergroup and usergroup.CAMI_Source != 'Bolt' then return end

  CAMI.RegisterUsergroup({ Name = role_id, Inherits = engine_parents[role_id] or role.base or 'user' }, 'Bolt')
end

--- Makes a usergroup of another admin mod a Bolt role of the same ID, so that it can be given
-- and edited. A registered usergroup that it inherits from and that is no role yet is made
-- one first. The role is based on the role its `Inherits` usergroup stands for, see
-- `Bolt:role_for_cami_group`, or on `user`, and has the immunity of that role. Does nothing
-- for the usergroups that CAMI defines itself and for a usergroup that already is a role.
-- @param usergroup [Map CAMI usergroup: Name and Inherits]
-- @param source [Any the admin mod that registered the usergroup]
function Bolt:import_cami_usergroup(usergroup, source)
  local name = istable(usergroup) and usergroup.Name

  if !isstring(name) or name == '' or engine_groups[name] or importing[name] or self:find_group(name) then return end

  local parent = CAMI.GetUsergroup(usergroup.Inherits)

  importing[name] = true

  if parent and parent.CAMI_Source != 'Bolt' then
    self:import_cami_usergroup(parent, parent.CAMI_Source)
  end

  importing[name] = nil

  local base = self:role_for_cami_group(usergroup.Inherits) or 'user'
  local role = Role.new(name)
    role.role_id = name
    role.name = name
    role.description = name
    role.base = base
    role.immunity = self:find_group(base):get_immunity()
    role.cami_source = tostring(source or 'CAMI')
  role:register()
end

--- Makes a privilege of another addon a Bolt permission under the 'cami' category, allowed to
-- the role its `MinAccess` stands for and to the roles based on that role: `user` for 'user',
-- `assistant` for 'admin' (also when MinAccess is missing or none of the three) and
-- `gamemaster` for 'superadmin'. Server owners change that like any permission. Does nothing
-- for a privilege that is a Bolt permission already.
-- @param privilege [Map CAMI privilege: Name, MinAccess and Description]
function Bolt:import_cami_privilege(privilege)
  local name = istable(privilege) and privilege.Name

  if !isstring(name) or name == '' or self:get_permission(name) then return end

  self:register_permission(name, name, privilege.Description, 'permission.categories.cami')

  imported_privileges[name] = true

  local role = self:find_group(engine_roles[privilege.MinAccess] or 'assistant')

  if role then
    self:merge_permissions(role, { anything = { [name] = { allowed = true } } })
  end
end

--- Removes the permission that a privilege of another addon has become, once the addon has
-- unregistered the privilege. Does nothing for the other permissions.
-- @param name [String privilege name]
function Bolt:remove_cami_privilege(name)
  if !imported_privileges[name] then return end

  imported_privileges[name] = nil

  self:remove_permission(name)
end

--- Returns the usergroup of CAMI that a permission is meant for: the one that the lowest of
-- Bolt's default roles that allows the permission stands for ('user' for `user`, 'admin' for
-- `assistant`, 'superadmin' for `gamemaster` and `admin`), and 'superadmin' if none does.
-- @param perm_id [String permission ID]
-- @return [String 'user', 'admin' or 'superadmin']
function Bolt:get_cami_min_access(perm_id)
  for _, entry in ipairs(role_access) do
    if self:role_allows(self:find_group(entry[1]), perm_id) then
      return entry[2]
    end
  end

  return 'superadmin'
end

--- Registers a Bolt permission as a privilege of CAMI, meant for the usergroup that
-- `Bolt:get_cami_min_access` names. Does nothing when another addon has registered a
-- privilege of that name.
-- @param permission [Map permission data: id and description, or nil]
function Bolt:register_cami_privilege(permission)
  local perm_id = istable(permission) and permission.id

  if !isstring(perm_id) or (CAMI.GetPrivilege(perm_id) and !registered_privileges[perm_id]) then return end

  registered_privileges[perm_id] = true

  CAMI.RegisterPrivilege({
    Name = perm_id,
    MinAccess = self:get_cami_min_access(perm_id),
    Description = isstring(permission.description) and t(permission.description) or nil
  })
end

--- Asks CAMI whether a player has a permission that is registered as a privilege, for the
-- layer of `Bolt:get_permission_layer` that comes in place of the role. An action on an
-- object for which the player's role has an entry of its own is left to the role.
-- @param actor [Player]
-- @param action [String permission ID]
-- @param object=nil [String object name the permission was allowed for]
-- @return [Boolean the answer, nil when CAMI is not asked or does not answer right away]
function Bolt:ask_cami(actor, action, object)
  if !CAMI.GetPrivilege(action) then return end

  if object != nil then
    local role = self:get_group_role(actor:GetUserGroup())
    local entries = role and role.permissions[object]

    if entries and entries[action] then return end
  end

  local previous = cami_answer

  cami_answer = nil

  CAMI.PlayerHasAccess(actor, action, store_cami_answer)

  local answer = cami_answer

  cami_answer = previous

  return answer
end

--- Applies the mode that the `bolt_external_admin` config picks. In both modes, Bolt
-- registers its roles as usergroups. As the provider, it also takes over the usergroups and
-- privileges that other addons have registered so far. Deferring, it registers its
-- permissions as privileges. Running it again registers what has been added since.
function Bolt:setup_cami()
  self.cami_mode = self:get_cami_mode()

  for _, role in pairs(self:get_roles()) do
    self:register_cami_usergroup(role)
  end

  if self:uses_external_admin() then
    for _, permission in pairs(self:get_all_permissions()) do
      self:register_cami_privilege(permission)
    end

    return
  end

  for _, usergroup in pairs(CAMI.GetUsergroups()) do
    if usergroup.CAMI_Source != 'Bolt' then
      self:import_cami_usergroup(usergroup, usergroup.CAMI_Source)
    end
  end

  for _, privilege in pairs(CAMI.GetPrivileges()) do
    self:import_cami_privilege(privilege)
  end
end
