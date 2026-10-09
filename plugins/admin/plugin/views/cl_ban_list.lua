--- Ban list page of the admin panel, open to players with the permission of the Unban
-- command (`unban`): `fl_ban_list`, the bans of the server a page at a time with a search
-- field, and `fl_ban_row`, the line of a single ban with the button that lifts it.
-- The bans are kept on the server. The page asks for the page it shows whenever it opens,
-- the search or the page number changes, or the server reports that a ban was added or
-- lifted, and waits a moment before asking so that several changes make one request.
-- Themes can draw the lines themselves with the `PaintAdminRow` theme hook.

local request_delay = 0.3

--- The ban list page (`fl_ban_list`): a search field, the buttons that turn the pages and a
-- scrollable list with an `fl_ban_row` for every ban on the current page. The plugin calls
-- `set_bans` with what the server has sent and `request_bans` when the bans have changed.
-- Derives from `fl_base_panel`.
local PANEL = {}

--- Creates the search field, the page buttons and the scroll panel that holds the list,
-- asks the server for the first page and makes the panel known to the plugin.
function PANEL:Init()
  local text_color = Theme.get_color('text')
  local small_font = Theme.get_font('text_small')
  local search_hint = t'ui.admin.bans.search'

  self.page = 1
  self.pages = 1
  self.search_text = ''

  self.search_entry = vgui.Create('fl_text_entry', self)
  self.search_entry:SetFont(small_font)
  self.search_entry:set_limit(64)
  self.search_entry.OnChange = function(pnl)
    self.search_text = pnl:GetValue()

    self:request_bans(1)
  end

  self.search_entry.PaintOver = function(pnl, w, h)
    if pnl:GetValue() == '' and !pnl:HasFocus() then
      draw.SimpleText(
        search_hint,
        small_font,
        math.scale(6),
        h * 0.5,
        text_color:darken(40),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
      )
    end
  end

  self.previous_button = vgui.Create('fl_button', self)
  self.previous_button:SetDrawBackground(false)
  self.previous_button:set_icon('fa-chevron-left')
  self.previous_button:set_centered(true)
  self.previous_button.DoClick = function(btn)
    self:request_bans(self.page - 1)
  end

  self.next_button = vgui.Create('fl_button', self)
  self.next_button:SetDrawBackground(false)
  self.next_button:set_icon('fa-chevron-right')
  self.next_button:set_centered(true)
  self.next_button.DoClick = function(btn)
    self:request_bans(self.page + 1)
  end

  self.page_label = vgui.Create('DLabel', self)
  self.page_label:SetFont(small_font)
  self.page_label:SetTextColor(text_color)
  self.page_label:SetContentAlignment(5)
  self.page_label:SetText('')

  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self:show_notice(t'ui.admin.loading')
  self:request_bans(1, true)

  Bolt.ban_list = self
end

--- Sends the request for a page once the delay since the last change has passed.
function PANEL:Think()
  self.BaseClass.Think(self)

  if self.request_at and self.request_at <= CurTime() then
    self.request_at = nil

    Cable.send('fl_bolt_bans_request', self.page, self.search_text)
  end
end

--- Puts the search field and the page buttons in a bar at the top and the list below it.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)
  local bar_height = math.scale(32)
  local label_width = math.scale(280)
  local search_width = w - label_width - bar_height * 2 - padding * 5

  self.search_entry:SetPos(padding, padding)
  self.search_entry:SetSize(search_width, bar_height)

  self.previous_button:SetPos(search_width + padding * 2, padding)
  self.previous_button:SetSize(bar_height, bar_height)
  self.previous_button:set_icon_size(math.floor(bar_height * 0.6))

  self.page_label:SetPos(search_width + bar_height + padding * 3, padding)
  self.page_label:SetSize(label_width, bar_height)

  self.next_button:SetPos(w - bar_height - padding, padding)
  self.next_button:SetSize(bar_height, bar_height)
  self.next_button:set_icon_size(math.floor(bar_height * 0.6))

  self.scroll_panel:SetPos(padding, bar_height + padding * 2)
  self.scroll_panel:SetSize(w - padding * 2, h - bar_height - padding * 3)
end

--- Asks the server for a page of the ban list, after a short delay that lets several
-- changes in a row make a single request.
-- @param page=nil [Number page to ask for; the current page by default]
-- @param immediately=false [Boolean send the request on the next frame]
function PANEL:request_bans(page, immediately)
  self.page = math.max(tonumber(page) or self.page, 1)
  self.request_at = CurTime() + (immediately and 0 or request_delay)
end

--- Replaces the list with a single line of text, such as the notice that there are no bans.
-- @param text [String]
function PANEL:show_notice(text)
  self.scroll_panel:Clear()

  local notice = self.scroll_panel:Add('DLabel')
  notice:SetText(text)
  notice:SetFont(Theme.get_font('text_small'))
  notice:SetTextColor(Theme.get_color('text'))
  notice:SetContentAlignment(5)
  notice:SizeToContents()
  notice:Dock(TOP)
  notice:DockMargin(0, math.scale(16), 0, 0)
end

--- Shows a page of bans that the server has sent: recreates the rows and updates the page
-- number and the page buttons.
-- @param data [Map the page: page (its number), pages (how many there are), total (how many
--   bans match the search) and bans (a List of rows with the steam_id, name, reason, admin,
--   permanent and time_left fields)]
function PANEL:set_bans(data)
  if !istable(data) or !istable(data.bans) then return end

  local row_height = math.scale(56)

  self.page = tonumber(data.page) or 1
  self.pages = tonumber(data.pages) or 1

  self.page_label:SetText(t('ui.admin.bans.page', {
    page = self.page,
    pages = self.pages,
    count = tonumber(data.total) or #data.bans
  }))

  self.previous_button:set_enabled(self.page > 1)
  self.next_button:set_enabled(self.page < self.pages)

  if #data.bans == 0 then
    self:show_notice(t'ui.admin.bans.empty')

    return
  end

  self.scroll_panel:Clear()

  for k, v in ipairs(data.bans) do
    if istable(v) then
      local row = self.scroll_panel:Add('fl_ban_row')
      row:SetTall(row_height)
      row:Dock(TOP)
      row:set_dark(k % 2 == 1)
      row:set_ban(v)
    end
  end
end

vgui.Register('fl_ban_list', PANEL, 'fl_base_panel')

--- The line of one ban in the ban list (`fl_ban_row`): the name and the SteamID of the
-- banned player, the reason and who issued the ban, the time the ban has left and a button
-- that lifts it after a confirmation. Assign the ban with `set_ban`.
-- Derives from `fl_base_panel`.
local PANEL = {}
PANEL.dark = false

--- Creates the labels of the row and the button that lifts the ban.
function PANEL:Init()
  local text_color = Theme.get_color('text')

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetFont(Theme.get_font('text_small'))
  self.name_label:SetTextColor(text_color)

  self.reason_label = vgui.Create('DLabel', self)
  self.reason_label:SetFont(Theme.get_font('text_smaller'))
  self.reason_label:SetTextColor(text_color:darken(30))

  self.time_label = vgui.Create('DLabel', self)
  self.time_label:SetFont(Theme.get_font('text_small'))
  self.time_label:SetTextColor(text_color)
  self.time_label:SetContentAlignment(6)

  self.unban_button = vgui.Create('fl_button', self)
  self.unban_button:SetDrawBackground(true)
  self.unban_button:SetFont(Theme.get_font('text_small'))
  self.unban_button:set_text(t'ui.admin.bans.unban')
  self.unban_button:set_icon('fa-unlock')
  self.unban_button:set_icon_size(math.scale(16))
  self.unban_button:set_text_offset(math.scale(8))
  self.unban_button:set_centered(true)
  self.unban_button:set_background_color(Theme.get_color('background_light'))
  self.unban_button:SizeToContentsX()
  self.unban_button.DoClick = function(btn)
    self:unban()
  end
end

--- Draws a darker background on the rows that are marked as dark, unless the active theme
-- draws the row in its PaintAdminRow hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintAdminRow', self, w, h) == nil and self.dark then
    draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background'):alpha(150))
  end
end

--- Puts the name above the reason on the left, and the time left and the unban button on
-- the right.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)
  local half = math.floor(h / 2)
  local button_w = self.unban_button:GetWide()
  local time_width = math.scale(200)
  local text_width = w - button_w - time_width - padding * 4

  self.name_label:SetPos(padding, 0)
  self.name_label:SetSize(text_width, half)

  self.reason_label:SetPos(padding, half)
  self.reason_label:SetSize(text_width, h - half)

  self.time_label:SetPos(text_width + padding * 2, 0)
  self.time_label:SetSize(time_width, h)

  self.unban_button:SetTall(h - padding * 2)
  self.unban_button:SetPos(w - button_w - padding, padding)
end

--- Sets whether the row is drawn with a darker background, which the page does for every
-- other row.
-- @param dark [Boolean]
function PANEL:set_dark(dark)
  self.dark = dark
end

--- Sets the ban this row stands for and fills in its texts. The reason is the tooltip of
-- the row as well, for when it does not fit.
-- @param ban [Map row of the ban list with the steam_id, name, reason, admin, permanent and
--   time_left fields]
function PANEL:set_ban(ban)
  local steam_id = tostring(ban.steam_id)
  local name = tostring(ban.name or steam_id)
  local reason = t(tostring(ban.reason or 'ui.no_reason'))
  local details = reason

  self.ban = ban

  if ban.admin then
    details = details..' / '..t('ui.admin.bans.banned_by', {
      admin = (string.gsub(tostring(ban.admin), '%%', '%%%%'))
    })
  end

  if ban.permanent then
    self.time_label:SetText(t'ui.admin.bans.permanent')
  elseif (tonumber(ban.time_left) or 0) <= 0 then
    self.time_label:SetText(t'ui.admin.bans.expired')
  else
    self.time_label:SetText(Flux.Lang:nice_time(ban.time_left))
  end

  self.name_label:SetText(name == steam_id and steam_id or name..' ('..steam_id..')')
  self.reason_label:SetText(details)

  self:SetTooltip(reason)
end

--- Returns the ban this row stands for.
-- @return [Map row of the ban list, or nil if it has not been set yet]
function PANEL:get_ban()
  return self.ban
end

--- Asks the player to confirm and then asks the server to lift the ban of this row.
function PANEL:unban()
  local ban = self.ban

  if !ban then return end

  local title, yes, no = t'ui.admin.bans.unban', t'ui.yes', t'ui.no'
  local message = t('ui.admin.bans.unban_message', {
    name = (string.gsub(tostring(ban.name or ban.steam_id), '%%', '%%%%'))
  })

  Derma_Query(message, title, yes, function()
    Cable.send('fl_bolt_unban', ban.steam_id)
  end, no)
end

vgui.Register('fl_ban_row', PANEL, 'fl_base_panel')
