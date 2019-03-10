local PANEL = {}
PANEL.message_data = {}
PANEL.compiled = {}
PANEL.added_at = 0
PANEL.force_show = false
PANEL.force_alpha = false
PANEL.should_paint = false
PANEL.alpha = 255

function PANEL:Init()
  --if PLAYER:can('chat_mod') then
  -- self.moderation = vgui.Create('fl_chat_moderation', self)
  --end

  self.added_at = CurTime()
  self.fade_at = self.added_at + config.get('chatbox_message_fade_delay')
end

function PANEL:Think()
  local cur_time = CurTime()

  self.should_paint = false

  if chatbox.panel:typing_command() then
    self.force_alpha = 50
  else
    self.force_alpha = false
  end

  if self.force_show then
    self.should_paint = true

    if self.force_alpha then
      self.alpha = self.force_alpha
    else
      self.alpha = 255
    end
  elseif self.fade_at > cur_time then
    self.should_paint = true

    local diff = self.fade_at - cur_time

    if diff < 1 then
      self.alpha = Lerp(FrameTime() * 6, self.alpha, 0)
    end
  else
    self.alpha = 0
  end
end

function PANEL:Paint(w, h)
  if self.should_paint then
    if plugin.call('ChatboxPrePaintMessage', w, h, self) == true then return end

    local cur_color = Color(255, 255, 255, self.alpha)
    local cur_font = Font.size(Theme.get_font('chatbox_normal'), Font.scale(20))

    for k, v in ipairs(self.message_data) do
      if istable(v) then
        if v.text then
          draw.SimpleTextOutlined(v.text, cur_font, v.x, v.y, cur_color, nil, nil, 1, Color(30, 30, 30, self.alpha))
        elseif IsColor(v) then
          cur_color = v:alpha(self.alpha)
        elseif v.image then
          draw.textured_rect(util.get_material(v.image), v.x, v.y, v.w, v.h, Color(255, 255, 255, self.alpha))
        end
      elseif isnumber(v) then
        cur_font = Font.size(Theme.get_font('chatbox_normal'), v)
      end
    end
  end
end

function PANEL:set_message(msg_info)
  local parent = chatbox.panel

  if !IsValid(parent) then return end

  self.message_data = msg_info

  self:SetSize(self:GetWide() - parent.padding * 0.5, msg_info.total_height)
end

-- Those people want us gone :(
function PANEL:eject()
  if plugin.call('ShouldMessageeject', self) != false then
    local parent = chatbox.panel

    if !IsValid(parent) then return end

    parent:remove_message(self.msg_index or 1)
    parent:rebuild_history_indexes()

    self:safe_remove()
  end
end

vgui.Register('fl_chat_message', PANEL, 'fl_base_panel')
