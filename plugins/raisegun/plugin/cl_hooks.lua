--- Client side of the Raise Weapon plugin: holds the view model of a lowered weapon in its
-- lowered pose and keeps the attack keys of the local player out of their commands while
-- their weapon is lowered.

local rotation_translate = {
  ['default'] = Angle(30, -30, -25),
  ['weapon_fists'] = Angle(30, -30, -50)
}

local lowered_offset = Vector()

--- Works out the lowered pose of a weapon: how far its view model is turned and moved
-- when the weapon is fully lowered.
-- The angles come from the `lowered_angles` field of the item that gives the weapon, the
-- `LoweredAngles` field of the weapon or the defaults of the plugin, the origin from
-- `lowered_origin`, `LoweredOrigin` or no offset. The AdjustWeaponLoweredView hook can
-- replace either.
-- @param weapon [Weapon]
-- @return [Angle rotation around the up (pitch field), forward (yaw field) and right (roll
--   field) axes of the view, Vector offset to the right (x), forward (y) and up (z)]
local function lowered_view(weapon)
  local class = weapon:GetClass()
  local item_obj = RaiseGun:find_weapon_item(class)
  local angles = RaiseGun:weapon_option(weapon, class, 'lowered_angles', 'LoweredAngles')
    or rotation_translate[class] or rotation_translate['default']
  local origin = RaiseGun:weapon_option(weapon, class, 'lowered_origin', 'LoweredOrigin') or vector_origin

  --- Lets plugins change the lowered pose of a weapon.
  -- Called on the client on every frame the view model of the local player's weapon is
  -- positioned while the weapon is lowered or on its way up or down; not while it is fully
  -- raised. The angles and the origin that are passed in are shared between calls: return
  -- new ones rather than changing them.
  -- @param weapon [Weapon The active weapon of the local player]
  -- @param angles [Angle How far the lowered view model is turned around the up (pitch
  --   field), forward (yaw field) and right (roll field) axes of the view]
  -- @param origin [Vector How far the lowered view model is moved to the right (x), forward
  --   (y) and up (z)]
  -- @param item_obj [Item Template of the item that gives the weapon, nil if there is none]
  -- @return [Angle Angles to use instead, Vector Origin to use instead. The origin can be left
  --   out to keep it; a handler that only changes the origin has to return the angles it
  --   was given in front of it, since a nil first value counts as no answer]
  local new_angles, new_origin = hook.Run('AdjustWeaponLoweredView', weapon, angles, origin, item_obj)

  return new_angles or angles, new_origin or origin
end

--- Turns and moves the view model into the lowered pose while the local player's weapon is
-- not raised, then lets the weapon's GetViewModelPosition and CalcViewModelView adjust it.
-- The pose eases in and out over `PLAYER.curRaisedFrac`, from 0 (raised) to 100 (lowered),
-- and snaps to either end once it is close; while the weapon is fully raised the view model
-- is left as it is, apart from what the weapon itself adjusts.
-- @param weapon [Weapon]
-- @param view_model [Entity]
-- @param old_eye_pos [Vector]
-- @param old_eye_angles [Angle]
-- @param eye_pos [Vector]
-- @param eye_angles [Angle]
-- @return [Vector view model position, Angle view model angles; nothing if the weapon
--   is not valid]
function RaiseGun:CalcViewModelView(weapon, view_model, old_eye_pos, old_eye_angles, eye_pos, eye_angles)
  if !IsValid(weapon) then
    return
  end

  local target_val = PLAYER:is_weapon_raised() and 0 or 100
  local current = PLAYER.curRaisedFrac or 0
  local fraction = current / 100

  current = Lerp(FrameTime() * 2, current, target_val)

  if math.abs(current - target_val) < 0.1 then
    current = target_val
  end

  PLAYER.curRaisedFrac = current

  local offset

  if fraction > 0 then
    local rotation, origin = lowered_view(weapon)

    eye_angles:RotateAroundAxis(eye_angles:Up(), rotation.p * fraction)
    eye_angles:RotateAroundAxis(eye_angles:Forward(), rotation.y * fraction)
    eye_angles:RotateAroundAxis(eye_angles:Right(), rotation.r * fraction)

    if origin.x != 0 or origin.y != 0 or origin.z != 0 then
      offset = lowered_offset

      offset:Set(eye_angles:Right())
      offset:Mul(origin.x)
      offset:Add(eye_angles:Forward() * origin.y)
      offset:Add(eye_angles:Up() * origin.z)
      offset:Mul(fraction)
    end
  end

  view_model:SetAngles(eye_angles)

  if weapon.GetViewModelPosition then
    local position, angles = weapon:GetViewModelPosition(eye_pos, eye_angles)

    old_eye_pos = position or old_eye_pos
    eye_angles = angles or eye_angles
  end

  if weapon.CalcViewModelView then
    local position, angles = weapon:CalcViewModelView(view_model, old_eye_pos, old_eye_angles, eye_pos, eye_angles)

    old_eye_pos = position or old_eye_pos
    eye_angles = angles or eye_angles
  end

  if offset then
    return old_eye_pos + offset, eye_angles
  end

  return old_eye_pos, eye_angles
end

--- Removes the attack keys from the command when the CanPlayerAttack hook returns false.
-- @param actor [Player]
-- @param user_cmd [CUserCmd]
function RaiseGun:StartCommand(actor, user_cmd)
  --- Asks whether the local player may attack.
  -- Called on the client for every user command that is built; the plugin's own handler
  -- denies it while the weapon is lowered.
  -- @return [Boolean Return false to strip the primary and secondary attack keys from the
  --   command]
  if hook.Run('CanPlayerAttack') == false then
    user_cmd:RemoveKey(IN_ATTACK + IN_ATTACK2)
  end
end

--- Prevents the local player from attacking while their weapon is lowered, unless it is a
-- weapon that is never raised: such a weapon is used in the lowered pose.
-- @return [Boolean false if the weapon is lowered, nil otherwise]
function RaiseGun:CanPlayerAttack()
  if !PLAYER:is_weapon_raised() then
    local weapon = PLAYER:GetActiveWeapon()

    if !IsValid(weapon) or self:get_fixed_state(weapon) != false then
      return false
    end
  end
end
