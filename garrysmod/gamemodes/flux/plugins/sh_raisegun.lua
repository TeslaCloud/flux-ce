PLUGIN:set_name('Raise Weapon')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Allows weapons to be lowered and raised by holding R key.')

BOOL_WEAPON_RAISED = 1

local rotation_translate = {
  ['default'] = Angle(30, -30, -25),
  ['weapon_fists'] = Angle(30, -30, -50)
}

local blocked_weapons = {
  ['weapon_physgun'] = true,
  ['gmod_tool'] = true,
  ['gmod_camera'] = true,
  ['weapon_physcannon'] = true
}

if CLIENT then
  function PLUGIN:CalcViewModelView(weapon, view_model, old_eye_pos, old_eye_angles, eye_pos, eye_angles)
    if !IsValid(weapon) then
      return
    end

    local target_val = 0

    if !fl.client:is_weapon_raised() then
      target_val = 100
    end

    local fraction = (fl.client.curRaisedFrac or 0) / 100
    local rotation = rotation_translate[weapon:GetClass()] or rotation_translate['default']

    eye_angles:RotateAroundAxis(eye_angles:Up(), rotation.p * fraction)
    eye_angles:RotateAroundAxis(eye_angles:Forward(), rotation.y * fraction)
    eye_angles:RotateAroundAxis(eye_angles:Right(), rotation.r * fraction)

    fl.client.curRaisedFrac = Lerp(FrameTime() * 2, fl.client.curRaisedFrac or 0, target_val)

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

    return old_eye_pos, eye_angles
  end
end

function PLUGIN:KeyPress(player, key)
  if key == IN_RELOAD then
    timer.Create('WeaponRaise'..player:SteamID(), 1, 1, function()
      player:toggle_weapon_raised()
    end)
  end
end

function PLUGIN:KeyRelease(player, key)
  if key == IN_RELOAD then
    timer.Remove('WeaponRaise'..player:SteamID())
  end
end

function PLUGIN:PlayerSwitchWeapon(player, old_weapon, new_weapon)
  player:set_weapon_raised(false)
end

function PLUGIN:OnWeaponRaised(player, weapon, raised)
  if IsValid(weapon) then
    local cur_time = CurTime()

    hook.run('UpdateWeaponRaised', player, weapon, raised, cur_time)
  end
end

function PLUGIN:UpdateWeaponRaised(player, weapon, raised, cur_time)
  if raised or blocked_weapons[weapon:GetClass()] then
    weapon:SetNextPrimaryFire(cur_time)
    weapon:SetNextSecondaryFire(cur_time)

    if weapon.OnRaised then
      weapon:OnRaised(player, cur_time)
    end
  else
    weapon:SetNextPrimaryFire(cur_time + 60)
    weapon:SetNextSecondaryFire(cur_time + 60)

    if weapon.OnLowered then
      weapon:OnLowered(player, cur_time)
    end
  end
end

function PLUGIN:PlayerThink(player, cur_time)
  local weapon = player:GetActiveWeapon()

  if IsValid(weapon) then
    if !player:is_weapon_raised() then
      weapon:SetNextPrimaryFire(cur_time + 60)
      weapon:SetNextSecondaryFire(cur_time + 60)
    end
  end
end

function PLUGIN:ModelWeaponRaised(player, model)
  return player:is_weapon_raised()
end

function PLUGIN:PlayerSetupDataTables(player)
  player:DTVar('Bool', BOOL_WEAPON_RAISED, 'WeaponRaised')
end

local player_meta = FindMetaTable('Player')

function player_meta:set_weapon_raised(raised)
  if SERVER then
    self:SetDTBool(BOOL_WEAPON_RAISED, raised)

    hook.run('OnWeaponRaised', self, self:GetActiveWeapon(), raised)
  end
end

function player_meta:is_weapon_raised()
  local weapon = self:GetActiveWeapon()

  if !IsValid(weapon) then
    return false
  end

  if blocked_weapons[weapon:GetClass()] then
    return true
  end

  local should_raise = hook.run('ShouldWeaponBeRaised', self, weapon)

  if should_raise then
    return should_raise
  end

  if self:GetDTBool(BOOL_WEAPON_RAISED) then
    return true
  end

  return false
end

function player_meta:toggle_weapon_raised()
  if self:is_weapon_raised() then
    self:set_weapon_raised(false)
  else
    self:set_weapon_raised(true)
  end
end
