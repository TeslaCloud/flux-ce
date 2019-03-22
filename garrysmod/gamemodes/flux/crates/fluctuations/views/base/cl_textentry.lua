
local PANEL = {}
PANEL.limit = 0

function PANEL:Init()
  self:SetUpdateOnType(true)
end

function PANEL:Paint(w, h)
  if !hook.run('ChatboxEntryPaint', self, 0, 0, w, h) then
    draw.RoundedBox(2, 0, 0, w, h, Theme.get_color('background'))

    self:DrawTextEntryText(Theme.get_color('text'), Theme.get_color('accent'), Theme.get_color('text'))
  end
end

function PANEL:Think()
  local text = self:GetValue()

  if text and text != '' then
    if utf8.len(text) > self.limit then
      self:SetValue(string.utf8sub(text, 1, self.limit))
    end
  end
end

function PANEL:set_limit(limit)
  PANEL.limit = math.abs(limit or 0)
end

vgui.Register('fl_text_entry', PANEL, 'DTextEntry')
