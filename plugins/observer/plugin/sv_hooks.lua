--- Server side of the Observer plugin: turns noclip into observer mode, takes a player who
-- dies in observer mode out of it, and keeps hidden players (vanished or observing) and
-- everything attached to them hidden as players join, respawn and change permissions.

--- Puts the player into observer mode in place of the default noclip, if they have the
-- 'noclip' permission. See Observer#start_observing.
-- @param actor [Player]
-- @return [Boolean always false, which blocks the default noclip]
function Observer:PlayerCanEnterNoclip(actor)
  if !actor:can('noclip') then
    actor:notify('error.no_permission')

    return false
  end

  self:start_observing(actor)

  return false
end

--- Takes the player out of observer mode in place of the default noclip. See
-- Observer#stop_observing.
-- @param actor [Player]
-- @return [Boolean always false, which blocks the default noclip]
function Observer:PlayerCanExitNoclip(actor)
  self:stop_observing(actor)

  return false
end

--- Keeps players where they are when leaving observer mode if the 'observer_reset' config
-- is off.
-- @param _actor [Player]
-- @return [Boolean false if the player should not be moved back, nil otherwise]
function Observer:ShouldObserverReset(_actor)
  if !Config.get('observer_reset') then
    return false
  end
end

--- Takes a player who dies in observer mode out of it, so that they do not respawn invisible
-- and invulnerable. They are not moved back to where they entered it.
-- @param victim [Player]
-- @param _inflictor [Entity]
-- @param _attacker [Entity]
function Observer:PlayerDeath(victim, _inflictor, _attacker)
  if !victim:get_nv('observer') then return end

  self:stop_observing(victim, false)
end

--- Hides hidden players from a newly connected player. The player's role is not known yet at
-- this point; Observer:PlayerRestored and Observer:PlayerInitialized show them again if the
-- player turns out to have the 'moderate' permission.
-- @param actor [Player the player that just connected]
function Observer:PlayerInitialSpawn(actor)
  actor:update_hidden_players()
end

--- Shows hidden players to a player whose role and permissions have been loaded, if they have
-- the 'moderate' permission.
-- @param actor [Player]
-- @param _record [User the player's database record]
function Observer:PlayerRestored(actor, _record)
  actor:update_hidden_players()
end

--- Applies once more which hidden players the player may see, now that their client is in the
-- game and their role is known.
-- @param actor [Player the player whose client has finished loading]
function Observer:PlayerInitialized(actor)
  actor:update_hidden_players()
end

--- Applies which hidden players the player may see after one of their permissions has changed.
-- @param target [Player]
-- @param _perm_id [String permission ID]
-- @param _value [Number new PERM_ value]
function Observer:PlayerPermissionChanged(target, _perm_id, _value)
  target:update_hidden_players()
end

--- Applies which hidden players the player may see after one of their temporary permissions
-- has changed.
-- @param target [Player]
-- @param _perm_id [String permission ID]
-- @param _value [Number new PERM_ value]
function Observer:PlayerTempPermissionChanged(target, _perm_id, _value)
  target:update_hidden_players()
end

--- Applies which hidden players the player may see after their role has changed.
-- @param target [Player]
-- @param _group [Role the player's new role, nil if its ID is not registered]
-- @param _old_group [Role the player's previous role]
function Observer:PlayerUserGroupChanged(target, _group, _old_group)
  target:update_hidden_players()
end

--- Makes a vanished player invisible again after a respawn, which has made them visible.
-- @param actor [Player]
function Observer:PostPlayerSpawn(actor)
  actor:hide_vanished_body()
end

do
  local created = {}

  local function get_holder(entity)
    local parent = entity:GetParent()

    while IsValid(parent) and !parent:IsPlayer() do
      parent = parent:GetParent()
    end

    if !IsValid(parent) and entity:IsWeapon() then
      parent = entity:GetOwner()
    end

    if IsValid(parent) and parent:IsPlayer() then
      return parent
    end
  end

  --- Hides the entities that have been attached to a hidden player since the last tick, such
  -- as the weapons they are given when they spawn or their flashlight, from everyone the
  -- player is hidden from. Hiding the player only hides what they have at that moment.
  local function hide_created()
    local entities = created

    created = {}

    for _, ent in ipairs(entities) do
      if IsValid(ent) then
        local holder = get_holder(ent)

        if holder and holder:is_hidden() then
          holder:update_visibility()
        end
      end
    end
  end

  --- Queues every new entity to be checked on the next tick, once it has been attached to
  -- whatever it belongs to.
  -- @param entity [Entity]
  function Observer:OnEntityCreated(entity)
    created[#created + 1] = entity

    if #created == 1 then
      timer.Simple(0, hide_created)
    end
  end

  --- Queues a weapon that a player picks up to be checked on the next tick, as it is not a
  -- new entity.
  -- @param weapon [Weapon]
  -- @param _actor [Player]
  function Observer:WeaponEquip(weapon, _actor)
    self:OnEntityCreated(weapon)
  end
end

--- Networks a weapon dropped by a hidden player to everyone again: it does not belong to the
-- player anymore.
-- @param _actor [Player]
-- @param weapon [Weapon]
function Observer:PlayerDroppedWeapon(_actor, weapon)
  if !IsValid(weapon) then return end

  for _, client in player.Iterator() do
    weapon:prevent_transmit(client, false)
  end
end

--- Keeps hidden players from picking up weapons that lie in the world. Weapons that they are
-- given are let through: those are created in the same tick.
-- @param actor [Player]
-- @param weapon [Weapon]
-- @return [Boolean false for a hidden player and a weapon that lies in the world]
function Observer:PlayerCanPickupWeapon(actor, weapon)
  if actor:is_hidden() and weapon:GetCreationTime() < CurTime() then
    return false
  end
end

--- Keeps hidden players from carrying objects in their hands, which would show other players
-- an object floating in the air.
-- @param actor [Player]
-- @param _entity [Entity]
-- @param _drag [Boolean]
-- @return [Boolean false for a hidden player]
function Observer:PlayerCanPickupObject(actor, _entity, _drag)
  if actor:is_hidden() then
    return false
  end
end
