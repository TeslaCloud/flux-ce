--- The Vendor Tool. Left click on a vendor opens its editor; left click anywhere else places
-- a new vendor there, facing the owner, with the model set in the tool's settings, and opens
-- the editor for it. Right click removes the vendor the owner is looking at. Reload on a
-- vendor picks it for moving, and reload anywhere else then moves it there. The tool requires
-- the `manage_vendors` permission, which each of its actions checks as well.

local IsValid = IsValid

TOOL.Category = 'Flux'
TOOL.Name = 'Vendor Tool'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'manage_vendors'

TOOL.ClientConVar['model'] = 'models/humans/group01/male_02.mdl'

--- Returns the angles of a vendor that stands at a position and faces a player.
-- @param position [Vector where the vendor stands]
-- @param owner [Player who the vendor faces]
-- @return [Angle]
local function facing_angles(position, owner)
  return Angle(0, (owner:GetPos() - position):Angle().yaw, 0)
end

--- Opens the editor of the vendor that was hit, or places a new vendor at the spot that was
-- hit and opens the editor for it.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if a vendor was placed or its editor opened (always true
--   clientside), false if nothing was hit or the vendor could not be created, nil if the
--   owner lacks the 'manage_vendors' permission]
function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('manage_vendors') then return end

  if Vendors:is_vendor(trace.Entity) then
    return Vendors:edit(owner, trace.Entity)
  end

  if !trace.Hit then return false end

  local vendor = Vendors:create(trace.HitPos, facing_angles(trace.HitPos, owner), {
    name = (t('vendor.default_name', nil, Flux.Lang:get_player_lang(owner))),
    model = self:GetClientInfo('model')
  })

  if !IsValid(vendor) then return false end

  Vendors:save()
  Vendors:edit(owner, vendor)

  owner:notify('notification.vendor.created')

  return true
end

--- Removes the vendor the tool owner is looking at.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if a vendor was removed (always true clientside), false if no vendor
--   was hit, nil if the owner lacks the 'manage_vendors' permission]
function TOOL:RightClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('manage_vendors') then return end

  if !Vendors:remove(trace.Entity) then
    owner:notify('error.vendor.not_vendor')

    return false
  end

  Vendors:save()

  owner:notify('notification.vendor.removed')

  return true
end

--- Picks the vendor that was hit for moving, or moves the vendor that was picked earlier to
-- the spot that was hit, facing the owner.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if a vendor was picked or moved (always true clientside), false if
--   there is no vendor to move, nil if the owner lacks the 'manage_vendors' permission]
function TOOL:Reload(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('manage_vendors') then return end

  if Vendors:is_vendor(trace.Entity) then
    owner.vendor_to_move = trace.Entity
    owner:notify('notification.vendor.picked')

    return true
  end

  if !trace.Hit or !Vendors:move(owner.vendor_to_move, trace.HitPos, facing_angles(trace.HitPos, owner)) then
    owner:notify('error.vendor.not_vendor')

    return false
  end

  owner.vendor_to_move = nil

  Vendors:save()

  owner:notify('notification.vendor.moved')

  return true
end

--- Builds the tool's settings panel: the model that new vendors get.
-- @param panel [Panel the tool's control panel]
function TOOL.BuildCPanel(panel)
  panel:AddControl('Header', { Description = t'tool.vendor.desc' })
  panel:AddControl('TextBox', { Label = t'tool.vendor.model', Command = 'vendor_model', MaxLenth = '192' })
end
