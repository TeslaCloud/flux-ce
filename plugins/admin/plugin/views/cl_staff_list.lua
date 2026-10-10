--- Staff page of the admin panel, open to players with the `manage_permissions` permission:
-- `fl_staff_list`, everybody whose role is not `user` grouped by role, whether they are on
-- the server or not, and `fl_staff_row`, the line of a single member with the button that
-- demotes them.
-- The list comes from the server, which reads the stored roles from the database; the page
-- asks for it when it opens and gets a new one after every demotion. The server only
-- demotes members whose role has a lower immunity than that of the player who asks (root
-- players may demote anyone).
-- Themes can draw the lines themselves with the `PaintAdminRow` theme hook.

--- The staff page (`fl_staff_list`): a scrollable list with a header for every role that
-- has members, the roles with the highest immunity first, and an `fl_staff_row` for every
-- member. The plugin calls `set_members` with what the server has sent.
-- Derives from `fl_base_panel`.
local PANEL = {}

--- Creates the scroll panel that holds the list, asks the server for the members and makes
-- the panel known to the plugin.
function PANEL:Init()
  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self:show_notice(t'ui.admin.loading')

  Bolt.staff_list = self

  Cable.send('fl_bolt_staff_request')
end

--- Lets the list fill the page.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)

  self.scroll_panel:SetPos(padding, padding)
  self.scroll_panel:SetSize(w - padding * 2, h - padding * 2)
end

--- Replaces the list with a single line of text, such as the notice that nobody is staff.
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

--- Shows the staff members that the server has sent: recreates the list, grouped by role.
-- Within a role the members who are on the server come first.
-- @param members [List<Map> members with the steam_id, name, role and online fields]
function PANEL:set_members(members)
  if !istable(members) then return end

  local text_color = Theme.get_color('text')
  local margin = math.scale(4)
  local row_height = math.scale(40)
  local by_role, role_ids, sort_names = {}, {}, {}

  for k, v in ipairs(members) do
    if istable(v) and isstring(v.steam_id) then
      local role_id = tostring(v.role)

      if !by_role[role_id] then
        by_role[role_id] = {}

        table.insert(role_ids, role_id)
      end

      table.insert(by_role[role_id], v)

      sort_names[v] = tostring(v.name):utf8lower()
    end
  end

  if #role_ids == 0 then
    self:show_notice(t'ui.admin.staff.empty')

    return
  end

  table.sort(role_ids, function(first, second)
    local first_role, second_role = Bolt:find_group(first), Bolt:find_group(second)
    local first_immunity = first_role and tonumber(first_role.immunity) or -1
    local second_immunity = second_role and tonumber(second_role.immunity) or -1

    if first_immunity == second_immunity then
      return first < second
    end

    return first_immunity > second_immunity
  end)

  self.scroll_panel:Clear()

  for k, v in ipairs(role_ids) do
    local role = Bolt:find_group(v)
    local role_members = by_role[v]

    table.sort(role_members, function(first, second)
      if first.online != second.online then
        return first.online == true
      end

      return sort_names[first] < sort_names[second]
    end)

    local header = self.scroll_panel:Add('DLabel')
    header:SetText((role and t(role.name) or v)..' ('..#role_members..')')
    header:SetFont(Theme.get_font('menu_normal'))
    header:SetTextColor(Theme.get_color('text_muted'))
    header:SizeToContents()
    header:Dock(TOP)
    header:DockMargin(margin, k == 1 and 0 or margin * 4, 0, margin)

    for k1, v1 in ipairs(role_members) do
      local row = self.scroll_panel:Add('fl_staff_row')
      row:SetTall(row_height)
      row:Dock(TOP)
      row:set_dark(k1 % 2 == 1)
      row:set_member(v1)
    end
  end
end

vgui.Register('fl_staff_list', PANEL, 'fl_base_panel')

--- The line of one staff member in the staff page (`fl_staff_row`): their name and SteamID,
-- whether they are on the server, and a button that demotes them to `user` after a
-- confirmation. Assign the member with `set_member`. Derives from `fl_base_panel`.
local PANEL = {}
PANEL.dark = false

--- Creates the labels of the row and the button that demotes the member.
function PANEL:Init()
  local text_color = Theme.get_color('text')

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetFont(Theme.get_font('text_small'))
  self.name_label:SetTextColor(text_color)

  self.status_label = vgui.Create('DLabel', self)
  self.status_label:SetFont(Theme.get_font('text_smaller'))
  self.status_label:SetTextColor(Theme.get_color('text_muted'))
  self.status_label:SetContentAlignment(6)

  self.demote_button = vgui.Create('fl_button', self)
  self.demote_button:SetDrawBackground(true)
  self.demote_button:set_draw_outline(true)
  self.demote_button:SetFont(Theme.get_font('text_small'))
  self.demote_button:set_text(t'ui.admin.staff.demote')
  self.demote_button:set_icon('fa-user-minus')
  self.demote_button:set_icon_size(math.scale(16))
  self.demote_button:set_text_offset(math.scale(8))
  self.demote_button:set_centered(true)
  self.demote_button:set_background_color(Theme.get_color('surface_raised'))
  self.demote_button:SizeToContentsX()
  self.demote_button.DoClick = function(btn)
    self:demote()
  end
end

--- Draws the row through the theme's PaintRow hook, unless the active theme draws it in its
-- PaintAdminRow hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintAdminRow', self, w, h) == nil then
    Theme.hook('PaintRow', self, w, h)
  end
end

--- Puts the name on the left, and the status and the demote button on the right.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)
  local button_w = self.demote_button:GetWide()
  local status_width = math.scale(120)
  local name_width = w - button_w - status_width - padding * 4

  self.name_label:SetPos(padding, 0)
  self.name_label:SetSize(name_width, h)

  self.status_label:SetPos(name_width + padding * 2, 0)
  self.status_label:SetSize(status_width, h)

  self.demote_button:SetTall(h - padding)
  self.demote_button:SetPos(w - button_w - padding, math.floor(padding * 0.5))
end

--- Sets whether the row is drawn with a darker background, which the page does for every
-- other row.
-- @param dark [Boolean]
function PANEL:set_dark(dark)
  self.dark = dark
end

--- Sets the staff member this row stands for and fills in their name and status.
-- @param member [Map member with the steam_id, name, role and online fields]
function PANEL:set_member(member)
  local steam_id = tostring(member.steam_id)
  local name = tostring(member.name or steam_id)

  self.member = member

  self.name_label:SetText(name == steam_id and steam_id or name..' ('..steam_id..')')

  if member.online then
    self.status_label:SetText(t'ui.admin.staff.online')
    self.status_label:SetTextColor(Theme.get_color('success'))
  else
    self.status_label:SetText(t'ui.admin.staff.offline')
    self.status_label:SetTextColor(Theme.get_color('text_muted'))
  end
end

--- Returns the staff member this row stands for.
-- @return [Map member, or nil if it has not been set yet]
function PANEL:get_member()
  return self.member
end

--- Asks the player to confirm and then asks the server to demote the member of this row.
function PANEL:demote()
  local member = self.member

  if !member then return end

  local title, yes, no = t'ui.admin.staff.demote', t'ui.yes', t'ui.no'
  local message = t('ui.admin.staff.demote_message', {
    name = tostring(member.name or member.steam_id),
    role = tostring(member.role)
  })

  Derma_Query(message, title, yes, function()
    Cable.send('fl_bolt_demote', member.steam_id)
  end, no)
end

vgui.Register('fl_staff_row', PANEL, 'fl_base_panel')
