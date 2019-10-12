
local PANEL = {}
PANEL.limit = 0

function PANEL:Init()
  self:SetDrawLanguageID(false)
  self:SetUpdateOnType(true)
end

function PANEL:Paint(w, h)
  if !hook.run('ChatboxEntryPaint', self, 0, 0, w, h) then
    draw.RoundedBox(2, 0, 0, w, h, Theme.get_color('background'))

    self:DrawTextEntryText(Theme.get_color('text'), Theme.get_color('accent'), Theme.get_color('text'))
  end
end

function PANEL:AllowInput(char)
  local text = self:GetValue()

  if text and text != '' then
    if self:get_limit() != 0 and utf8.len(text) >= self:get_limit() then
      return true
    end
  end
end

function PANEL:set_limit(limit)
  self.limit = math.abs(limit or 0)
end

function PANEL:get_limit()
  return self.limit or 0
end

vgui.Register('fl_text_entry', PANEL, 'DTextEntry')
