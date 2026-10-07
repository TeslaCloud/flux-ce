local PANEL = {}

--- Sets the tooltip and covers the avatar with an invisible button that opens the player's
-- Steam profile on left click and copies their SteamID on right click.
function PANEL:Init()
  self:SetTooltip(t'ui.avatar_tooltip')

  self.button = vgui.create('DButton', self)
  self.button:Dock(FILL)
  self.button:SetText('')
  self.button.Paint = function()
  end

  self.button.DoClick = function(pnl)
    local player = self.player

    if IsValid(player) then
      player:ShowProfile()
    end
  end

  self.button.DoRightClick = function(pnl)
    local player = self.player

    if IsValid(player) then
      SetClipboardText(player:SteamID())
    end
  end
end

--- Sets the player whose avatar is displayed and whom the click actions apply to.
-- @param player [Player]
-- @param size [Number avatar resolution passed to AvatarImage:SetPlayer, e.g. 32, 64 or 184]
function PANEL:set_player(player, size)
  self:SetPlayer(player, size)
  self.player = player
end

vgui.Register('fl_avatar_panel', PANEL, 'AvatarImage')
