local PANEL = {}

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

function PANEL:set_player(player, size)
  self:SetPlayer(player, size)
  self.player = player
end

vgui.Register('fl_avatar_panel', PANEL, 'AvatarImage')
