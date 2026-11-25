--- Server-side player extensions of the Observer plugin: vanishing, hiding and showing the
-- player's body, and keeping hidden players (vanished or observing) from being networked to
-- everyone without the 'moderate' permission.

local player_meta = FindMetaTable('Player')
const invisible_color = Color(0, 0, 0, 0)

--- Checks whether the player is hidden from other players: vanished, or in observer mode.
-- @return [Boolean]
function player_meta:is_hidden()
  return self.is_vanished == true or self:get_nv('observer') == true
end

--- Starts or stops networking the player, together with everything attached to them such as
-- their weapons, to one other player, going by whether the player is hidden and whether the
-- receiver has the 'moderate' permission, which lets them see hidden players.
-- @param receiver [Player]
function player_meta:update_transmit(receiver)
  if !IsValid(receiver) or receiver == self then return end

  local should_prevent = self:is_hidden() and !receiver:can('moderate')

  self:prevent_transmit(receiver, should_prevent)

  for _, weapon in ipairs(self:GetWeapons()) do
    weapon:prevent_transmit(receiver, should_prevent)
  end
end

--- Applies whether the player is hidden to the networking of the player to everyone else and
-- sets their own 'transmission_prevented' net var and the public 'hidden' net var, by which
-- clients keep the player off the scoreboard. Called whenever the player is hidden or shown,
-- and again whenever something new is attached to a hidden player.
function player_meta:update_visibility()
  local hidden = self:is_hidden()

  self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

  for _, client in player.Iterator() do
    self:update_transmit(client)
  end

  self:set_nv('transmission_prevented', hidden, self)
  self:set_nv('hidden', hidden)
end

--- Applies which of the hidden players this player may see to the networking of all of them.
-- Called when the player joins and whenever their permissions change.
function player_meta:update_hidden_players()
  for _, client in player.Iterator() do
    client:update_transmit(self)
  end
end

--- Makes the player invisible and not solid, without a shadow or a drawn weapon. The color
-- the player has while visible is kept for `Player:show_body` the first time they are hidden,
-- so hiding a player who is hidden already keeps it.
function player_meta:hide_body()
  if !self.visible_color then
    self.visible_color = self:GetColor()
  end

  self:DrawWorldModel(false)
  self:DrawShadow(false)
  self:SetNoDraw(true)
  self:SetNotSolid(true)
  self:SetColor(invisible_color)
end

--- Makes the player visible and solid again with the color they had before
-- `Player:hide_body`. The weapon is only drawn again when the player carries nothing in the
-- engine's hold (see `Player:get_holding_entity` of the Pickup Objects plugin), since the
-- engine drops the carried object as soon as the weapon is drawn and draws the weapon by
-- itself once the object is let go of. A dragged ragdoll is not in that hold and does not
-- keep the weapon hidden.
function player_meta:show_body()
  local held = PickupObjects and self:get_holding_entity()

  if !IsValid(held) or !held:IsPlayerHolding() then
    self:DrawWorldModel(true)
  end

  self:DrawShadow(true)
  self:SetNoDraw(false)
  self:SetNotSolid(false)

  if self.visible_color then
    self:SetColor(self.visible_color)
    self.visible_color = nil
  end
end

--- Makes a vanished player invisible and not solid again after they have respawned, unless
-- they are in observer mode, which hides them in its own way.
function player_meta:hide_vanished_body()
  if self.is_vanished and !self:get_nv('observer') then
    self:hide_body()
  end
end

--- Hides the player from everyone without the 'moderate' permission, or shows them again.
-- A player in observer mode keeps the look observer mode gave them; anyone else is made
-- invisible and not solid, and gets their visible color back when they reappear. A player
-- who leaves vanish while in observer mode stays hidden as an observer. Sets the player's
-- is_vanished field and notifies nobody.
-- @param should_vanish [Boolean true to hide the player, false to show them again]
function player_meta:set_vanished(should_vanish)
  if !self:get_nv('observer') then
    if should_vanish then
      self:hide_body()
    else
      self:show_body()
    end
  end

  self.is_vanished = should_vanish

  self:update_visibility()
end
