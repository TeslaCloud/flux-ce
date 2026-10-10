--- A role is a group of players that share a set of permissions, such as `moderator`.
-- A role has a name, a description, a color, an icon, an immunity level that
-- `Bolt:check_immunity` compares between players, and optionally a base role (`base`) whose
-- permissions it shares. Roles are normally defined by a file in a plugin's `roles` folder,
-- which fills in the `ROLE` global and may define `define_permissions` to allow or deny
-- actions with `can`, `cannot` and `allow_anything`; see `Role:register`. A player's role
-- is read with `Player:get_role` and set with `Player:SetUserGroup`.

class 'Role'

Role.name = 'Undefined'
Role.description = 'Undefined'
Role.color = Color(255, 255, 255)
Role.icon = 'icon16/user.png'
Role.immunity = 0
Role.protected = false
Role.base = nil

--- Sets the role's ID and gives it an empty permission table. Does nothing without an ID.
-- @param id [String role ID, normalized with string.to_id]
function Role:init(id)
  if !id then return end

  self.role_id = id:to_id()
  self.permissions = {}
end

--- Allows this role to perform an action, optionally only on one kind of object. If a callback
-- is given, it decides the outcome of each check.
-- ```
-- function ROLE:define_permissions()
--   self:allow('kick')
--   self:allow('noclip', nil, function(actor, object)
--     return actor:Alive()
--   end)
-- end
-- ```
-- @param action [String permission ID]
-- @param object='anything' [String/Map object name, or a class table whose class_name is used]
-- @param callback=nil [Function called as callback(actor, object) on every check; its return
--   value becomes the result]
function Role:allow(action, object, callback)
  object = (istable(object) and object.class_name) or
        (isstring(object) and object) or
        'anything'

  local perm = self.permissions[object] or {}
  perm[action] = {
    callback = callback,
    allowed = true
  }

  self.permissions[object] = perm
end

--- Explicitly denies an action for this role, overriding a permission inherited from its base.
-- @param action [String permission ID]
-- @param object='anything' [String/Map object name, or a class table whose class_name is used]
function Role:disallow(action, object)
  object = (istable(object) and object.class_name) or
        (isstring(object) and object) or
        'anything'

  local perm = self.permissions[object] or {}

  perm[action] = {
    allowed = false
  }

  self.permissions[object] = perm
end

--- Makes every permission check against this role pass.
function Role:allow_anything()
  self.can_anything = true
end

--- Checks whether this role allows an action. Only the role's own permission table is
-- consulted; use actor:can for the full check that includes per-player permissions.
-- @param actor [Player passed on to the permission's callback]
-- @param action [String permission ID; an empty string always passes]
-- @param object='anything' [String object name the permission was allowed for]
-- @return [Boolean whether the action is allowed (a permission callback's return value is
--   passed through as is)]
function Role:can(actor, action, object)
  if self.can_anything then return true end
  if action == '' then return true end

  local permissions = self.permissions[object or 'anything']

  if permissions then
    local perm = permissions[action]

    if perm then
      if perm.callback then
        return perm.callback(actor, object)
      else
        return perm.allowed
      end
    end
  end

  return false
end

--- Called when the player's role is being set to this role. Return any non-nil value to keep the
-- new role from being saved to the database.
-- @param target [Player]
-- @param old_group [Role the player's previous role]
function Role:on_role_set(target, old_group) end

--- Called when the player's role is taken or modified. Return any non-nil value to keep the new
-- role from being saved to the database.
-- @param target [Player]
-- @param new_group [Role the role the player is being given]
function Role:on_role_taken(target, new_group) end

--- Returns the role's ID.
-- @return [String]
function Role:get_id()
  return self.role_id
end

--- Returns the role's display name.
-- @return [String]
function Role:get_name()
  return self.name or 'Unknown'
end

--- Returns the role's description, usually a language phrase.
-- @return [String]
function Role:get_description()
  return self.description or 'This group has no description'
end

--- Returns the role's color.
-- @return [Color]
function Role:get_color()
  return self.color or Color('white')
end

--- Returns the role's immunity level, which Bolt:check_immunity compares between roles.
-- @return [Number]
function Role:get_immunity()
  return self.immunity or 0
end

--- Checks whether the role is flagged as protected.
-- @return [Boolean]
function Role:is_protected()
  return self.protected or false
end

--- Returns the role's permission table.
-- @return [Map permission entries (allowed, callback) keyed by object name, then by action]
function Role:get_permissions()
  return self.permissions or {}
end

--- Returns the role's icon.
-- @return [String icon path or Font Awesome icon name]
function Role:get_icon()
  return self.icon or 'icon16/user.png'
end

--- Returns the ID of the role this role is based on.
-- @return [String base role ID, or nil if there is none]
function Role:get_base()
  return self.base or nil
end

--- Registers the role with Bolt. If the role has a define_permissions method, it is run first
-- with the can, cannot and allow_anything globals temporarily bound to this role, followed
-- by the OnDefinePermissions hook.
-- ```
-- -- roles/sh_helper.lua
-- ROLE.name = 'Helper'
-- ROLE.immunity = 50
-- ROLE.base = 'user'
--
-- function ROLE:define_permissions()
--   can 'kick'
--   cannot 'ban'
-- end
-- ```
-- @see [Bolt#include_roles]
function Role:register()
  if self.define_permissions then
    local old_can, old_cannot, old_anything = can, cannot, allow_anything
      --- Allows an action for the role being registered. Replaces the global can only while
      -- define_permissions runs.
      -- @param action [String permission ID]
      -- @param object='anything' [String/Map object name or class table]
      -- @param callback=nil [Function called as callback(actor, object) on every check]
      -- @see [Role#allow]
      function can(action, object, callback)
        self:allow(action, object, callback)
      end

      --- Denies an action for the role being registered. Only defined while define_permissions
      -- runs.
      -- @param action [String permission ID]
      -- @param object='anything' [String/Map object name or class table]
      -- @see [Role#disallow]
      function cannot(action, object)
        self:disallow(action, object)
      end

      --- Lets the role being registered pass every permission check. Only defined while
      -- define_permissions runs; the arguments are ignored.
      -- @param action=nil [Any ignored]
      -- @param object=nil [Any ignored]
      -- @param callback=nil [Any ignored]
      -- @see [Role#allow_anything]
      function allow_anything(action, object, callback)
        self:allow_anything(action, object)
      end

      self:define_permissions()

      --- Called on both realms while a role is being registered, right after its
      -- `define_permissions` method has run. The `can`, `cannot` and `allow_anything` globals
      -- are still bound to the role, so a handler can adjust its permissions. Roles without
      -- a `define_permissions` method do not run this hook.
      -- @param role [Role The role being registered]
      hook.Run('OnDefinePermissions', self)

    can, cannot, allow_anything = old_can, old_cannot, old_anything
  end

  Bolt:create_role(self.role_id, self)
end

Role.get_parent = Role.get_base
