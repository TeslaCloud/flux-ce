--- A single message of the chatbox (`fl_chat_message`): draws a message compiled by
-- `Chatbox.compile` and fades out after the 'message_fade_delay' config, unless the chatbox is
-- open. Steam avatars in the message are `AvatarImage` child panels that the message draws
-- itself.

local simple_text_outlined = draw.SimpleTextOutlined
local text_color = Color(255, 255, 255)
local white_alpha = Color(255, 255, 255)
local outline_alpha = Color(30, 30, 30)

local PANEL = {}
PANEL.message_data = {}
PANEL.compiled = {}
PANEL.added_at = 0
PANEL.force_show = false
PANEL.force_alpha = false
PANEL.should_paint = false
PANEL.alpha = 255

--- Records when the message was added and when it should start to fade out.
function PANEL:Init()
  -- if PLAYER:can('chat_mod') then
  -- self.moderation = vgui.Create('fl_chat_moderation', self)
  -- end

  self.added_at = CurTime()
  self.fade_at = self.added_at + Config.get('message_fade_delay')
end

--- Updates the visibility and opacity of the message: fully visible while the chatbox
-- is open, dimmed while a command is being typed, fading out after the fade delay.
function PANEL:Think()
  local cur_time = CurTime()

  self.should_paint = false

  if Chatbox.panel:typing_command() then
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

--- Draws the texts, images, icons and avatars of the compiled message, unless the
-- ChatboxPrePaintMessage hook returns true.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  if self.should_paint then
    --- Lets plugins draw a chat message themselves. Called on the client every frame for each
    -- message that is visible, while its panel is being painted; gamemode hooks are not
    -- called.
    -- @param w [Number width of the message panel]
    -- @param h [Number height of the message panel]
    -- @param panel [Panel the fl_chat_message panel; its message_data field holds the compiled
    --   message and its alpha field the current opacity]
    -- @return [Boolean return true to skip the default drawing]
    if Plugin.call('ChatboxPrePaintMessage', w, h, self) == true then return end

    local alpha = self.alpha
    local message_data = self.message_data
    local cur_font = Font.size(Theme.get_font('chatbox_normal'), math.scale(Config.get('default_font_size')))

    text_color.r, text_color.g, text_color.b, text_color.a = 255, 255, 255, alpha
    white_alpha.a = alpha
    outline_alpha.a = alpha

    for i = 1, #message_data do
      local v = message_data[i]

      if istable(v) then
        if v.text then
          simple_text_outlined(v.text, cur_font, v.x, v.y, text_color, nil, nil, 1, outline_alpha)
        elseif IsColor(v) then
          text_color.r, text_color.g, text_color.b, text_color.a = v.r, v.g, v.b, alpha
        elseif v.image then
          draw.textured_rect(util.get_material(v.image), v.x, v.y, v.w, v.h, white_alpha)
        elseif v.icon then
          FontAwesome:draw(v.icon, v.x, v.y, v.h, white_alpha)
        elseif v.avatar then
          local avatar_panel = v.panel

          if IsValid(avatar_panel) then
            avatar_panel:SetAlpha(alpha)
            avatar_panel:PaintManual()
          end
        end
      elseif isnumber(v) then
        cur_font = Font.size(Theme.get_font('chatbox_normal'), v)
      end
    end
  end
end

--- Sets the compiled message to display, resizes the panel to its height and creates the
-- panels of its avatars. Does nothing if the chatbox panel does not exist.
-- @param msg_info [Map compiled message, as returned by Chatbox.compile]
function PANEL:set_message(msg_info)
  local parent = Chatbox.panel

  if !IsValid(parent) then return end

  self.message_data = msg_info

  self:SetSize(self:GetWide() - parent.padding * 0.5, msg_info.total_height)
  self:create_avatars()
end

--- Creates an `AvatarImage` panel for every avatar piece of the compiled message, replacing
-- the ones of the previous message. The panels are not drawn on their own: `PANEL:Paint` draws
-- them along with the rest of the message, so that they fade with it. A piece that holds a
-- SteamID64 shows the avatar even if that player is not on the server anymore.
function PANEL:create_avatars()
  for k, v in ipairs(self.avatars or {}) do
    if IsValid(v) then
      v:Remove()
    end
  end

  self.avatars = {}

  for k, v in ipairs(self.message_data) do
    if istable(v) and v.avatar and isnumber(v.w) and isnumber(v.h) then
      local source = v.avatar
      local target = isstring(source) and player.GetBySteamID64(source) or source
      local resolution = v.h > 32 and 64 or 32
      local avatar = vgui.Create('AvatarImage', self)

      avatar:SetPos(v.x, v.y)
      avatar:SetSize(v.w, v.h)
      avatar:SetMouseInputEnabled(false)
      avatar:SetPaintedManually(true)

      if isentity(target) and IsValid(target) and target:IsPlayer() then
        avatar:SetPlayer(target, resolution)
      elseif isstring(source) then
        avatar:SetSteamID(source, resolution)
      end

      v.panel = avatar

      self.avatars[#self.avatars + 1] = avatar
    end
  end
end

-- Those people want us gone :(

--- Removes the message from the chatbox history and deletes its panel,
-- unless the ShouldMessageeject hook returns false.
function PANEL:eject()
  --- Decides whether a message may be removed from the chatbox. Called on the client when the
  -- history is full and its oldest message is about to be ejected; gamemode hooks are not
  -- called.
  -- @param panel [Panel the fl_chat_message panel]
  -- @return [Boolean return false to keep the message]
  if Plugin.call('ShouldMessageeject', self) != false then
    local parent = Chatbox.panel

    if !IsValid(parent) then return end

    parent:remove_message(self.msg_index or 1)
    parent:rebuild_history_indexes()

    self:safe_remove()
  end
end

vgui.Register('fl_chat_message', PANEL, 'fl_base_panel')
