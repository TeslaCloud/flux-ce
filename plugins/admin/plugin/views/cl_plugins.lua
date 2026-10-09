--- Plugin manager page of the admin panel, which lets players with the `manage_plugins`
-- permission disable and enable plugins: `fl_plugin_manager`, the list of every plugin the
-- server knows of, and `fl_plugin_row`, the line of a single plugin.
-- The list is built from `Plugin.known`. A switch only changes what is saved: the plugin
-- itself is loaded or left out the next time the server starts or changes the map, which
-- the page says at its top and marks on every plugin that is waiting for a restart.
-- Themes can draw the lines themselves with the `PaintAdminRow` theme hook.

--- The plugin manager page (`fl_plugin_manager`): a notice about the restart and a
-- scrollable list with an `fl_plugin_row` for every known plugin. The plugin calls `rebuild`
-- when the server reports that a plugin has been disabled or enabled.
-- Derives from `fl_base_panel`.
local PANEL = {}

--- Creates the restart notice and the scroll panel that holds the list, fills the list and
-- makes the panel known to the plugin.
function PANEL:Init()
  self.notice = vgui.Create('DLabel', self)
  self.notice:SetFont(Theme.get_font('text_small'))
  self.notice:SetTextColor(Theme.get_color('text'))
  self.notice:SetText(t'ui.admin.plugins.notice')
  self.notice:SetWrap(true)
  self.notice:SetContentAlignment(7)

  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self:rebuild()

  Bolt.plugin_manager = self
end

--- Keeps the notice at the top of the page and the list below it.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)
  local notice_height = math.scale(48)

  self.notice:SetPos(padding, padding)
  self.notice:SetSize(w - padding * 2, notice_height)

  self.scroll_panel:SetPos(padding, notice_height + padding * 2)
  self.scroll_panel:SetSize(w - padding * 2, h - notice_height - padding * 3)
end

--- Recreates the list from Plugin.known: a row for every plugin, sorted by name.
function PANEL:rebuild()
  local row_height = math.scale(40)

  self.scroll_panel:Clear()

  for k, v in ipairs(Plugin.known()) do
    local row = self.scroll_panel:Add('fl_plugin_row')
    row:SetTall(row_height)
    row:Dock(TOP)
    row:set_dark(k % 2 == 1)
    row:set_plugin(v)
  end
end

vgui.Register('fl_plugin_manager', PANEL, 'fl_base_panel')

--- The line of one plugin in the plugin manager (`fl_plugin_row`): a switch that shows
-- whether the plugin is saved as enabled and toggles it, the name of the plugin and its
-- state in this session. Assign the plugin with `set_plugin`. The description, the
-- dependencies and the dependents of the plugin are the tooltip of the row.
-- Derives from `fl_base_panel`.
local PANEL = {}
PANEL.dark = false

--- Creates the switch and the labels for the name and the state of the plugin, and picks
-- the background color of the dark rows.
function PANEL:Init()
  self.dark_color = Theme.get_color('background'):alpha(150)

  self.toggle = vgui.Create('fl_button', self)
  self.toggle:SetDrawBackground(false)
  self.toggle:set_centered(true)
  self.toggle.DoClick = function(btn)
    self:toggle_plugin()
  end

  self.name_label = vgui.Create('DLabel', self)
  self.name_label:SetFont(Theme.get_font('text_small'))
  self.name_label:SetTextColor(Theme.get_color('text'))

  self.state_label = vgui.Create('DLabel', self)
  self.state_label:SetFont(Theme.get_font('text_smaller'))
  self.state_label:SetTextColor(Theme.get_color('text'))
  self.state_label:SetContentAlignment(6)
end

--- Draws a darker background on the rows that are marked as dark, unless the active theme
-- draws the row in its PaintAdminRow hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintAdminRow', self, w, h) == nil and self.dark then
    draw.RoundedBox(0, 0, 0, w, h, self.dark_color)
  end
end

--- Puts the switch on the left, the name after it and the state on the right.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)
  local toggle_size = h - padding
  local label_x = toggle_size + padding * 2
  local label_width = math.floor((w - label_x - padding) / 2)

  self.toggle:SetSize(toggle_size, toggle_size)
  self.toggle:SetPos(padding, math.floor(padding / 2))
  self.toggle:set_icon_size(math.floor(toggle_size * 0.75))

  self.name_label:SetPos(label_x, 0)
  self.name_label:SetSize(label_width, h)

  self.state_label:SetPos(label_x + label_width, 0)
  self.state_label:SetSize(label_width, h)
end

--- Sets whether the row is drawn with a darker background, which the page does for every
-- other row.
-- @param dark [Boolean]
function PANEL:set_dark(dark)
  self.dark = dark
end

--- Sets the plugin this row stands for and fills in its name, state, switch and tooltip.
-- The switch of the admin plugin itself is disabled, since the plugin manager is part of
-- it.
-- @param entry [Map plugin entry as returned by Plugin.known]
function PANEL:set_plugin(entry)
  local enabled_text, disabled_text = t'ui.admin.plugins.enabled', t'ui.admin.plugins.disabled'
  local name = entry.name
  local state = t('ui.admin.plugins.state.'..(entry.loaded and 'loaded' or (entry.reason or 'unknown')))
  local tooltip = {}

  self.entry = entry

  if entry.version then
    name = name..' '..tostring(entry.version)
  end

  if entry.restart_required then
    state = state..' / '..t('ui.admin.plugins.restart.'..(entry.disabled and 'disabled' or 'enabled'))

    self.state_label:SetTextColor(Theme.get_color('accent_light'))
  end

  self.name_label:SetText(name)
  self.state_label:SetText(state)

  self.toggle:set_icon(entry.disabled and 'fa-toggle-off' or 'fa-toggle-on')
  self.toggle:SetTooltip(entry.disabled and disabled_text or enabled_text)
  self.toggle:set_enabled(entry.id != Plugin.normalize_id(Bolt:get_path()))

  if isstring(entry.description) then
    table.insert(tooltip, (t(entry.description)))
  end

  if isstring(entry.author) then
    table.insert(tooltip, (t('ui.admin.plugins.author', { author = entry.author })))
  end

  if #entry.depends > 0 then
    table.insert(tooltip, (t('ui.admin.plugins.depends', { plugins = table.concat(entry.depends, ', ') })))
  end

  if #entry.required_by > 0 then
    table.insert(tooltip, (t('ui.admin.plugins.required_by', { plugins = table.concat(entry.required_by, ', ') })))
  end

  if #tooltip > 0 then
    self:SetTooltip(table.concat(tooltip, '\n'))
  end
end

--- Returns the plugin this row stands for.
-- @return [Map plugin entry, or nil if it has not been set yet]
function PANEL:get_plugin()
  return self.entry
end

--- Asks the server to enable the plugin if it is saved as disabled, and to disable it
-- otherwise. A plugin that the schema or other plugins depend on is only disabled after
-- the player has confirmed a warning that names them, and is then disabled by force.
function PANEL:toggle_plugin()
  local entry = self.entry

  if !entry then return end

  if entry.disabled or #entry.required_by == 0 then
    Cable.send('fl_bolt_plugin_set_disabled', entry.id, !entry.disabled, false)

    return
  end

  local title, confirm, cancel = t'ui.admin.plugins.force.title', t'ui.admin.plugins.force.confirm', t'ui.cancel'
  local message = t('ui.admin.plugins.force.message', {
    plugin = entry.name,
    plugins = table.concat(entry.required_by, ', ')
  })

  Derma_Query(message, title, confirm, function()
    Cable.send('fl_bolt_plugin_set_disabled', entry.id, true, true)
  end, cancel)
end

vgui.Register('fl_plugin_row', PANEL, 'fl_base_panel')
