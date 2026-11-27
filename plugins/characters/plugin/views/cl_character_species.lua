--- The species stage of character creation (`fl_char_create_species`): shows a button for
-- every option of `Characters.get_creation_options` and stores the chosen option in the
-- character data. The character creation screen leaves the stage out when there is only one
-- option (see `Characters:AddCharacterCreationMenuStages`).

local label_line_height = 2

local PANEL = {}
PANEL.id = 'species'
PANEL.text = 'ui.char_create.species'

--- Returns the option of the stage with the given ID.
-- @param id [String option ID]
-- @return [Map the option, nil when the stage has no such option]
function PANEL:find_option(id)
  for _, option in ipairs(self.options or {}) do
    if option.id == id then
      return option
    end
  end
end

--- Builds the option chooser with a button for every option of the local player, for the
-- extra data of the creation screen, preselecting the option chosen earlier. A button shows
-- the image of its option with the name below it, underlined in the color of the option if it
-- has one; the button of an option without an image shows only the name, centered. Picking an
-- option plays one of its sounds, and another option can be picked two seconds later.
-- @param parent [Panel the character creation menu]
function PANEL:on_open(parent)
  self.options = Characters.get_creation_options(PLAYER, parent.extra_data)
  self.option_id = parent.char_data.option or self.option_id

  self.chooser = vgui.Create('fl_horizontalbar', self)
  self.chooser:SetSize(self:GetWide(), self:GetTall() * 0.875 - math.scale(8))
  self.chooser:SetPos(0, self:GetTall() * 0.125 + math.scale(8))
  self.chooser:SetOverlap(math.scale(4))
  self.chooser:set_centered(true)

  local label_background = ColorAlpha(Theme.get_color('background'), 200)

  for _, option in ipairs(self.options) do
    local image = option.image
    local has_image = isstring(image) and image != ''
    local line_color = IsColor(option.color) and option.color or nil
    local button = vgui.Create('fl_image_button')
    button:SetSize(self.chooser:GetWide() * 0.33, self.chooser:GetTall())

    if has_image then
      button:SetImage(image)
    end

    if isstring(option.description) then
      button:SetTooltip(t(option.description))
    end

    if option.id == self.option_id then
      button:set_active(true)
      self.prev_button = button
    end

    local label = vgui.Create('DLabel', button)
    label:Dock(has_image ? BOTTOM : FILL)
    label:SetText(t(option.name))
    label:SetFont(Theme.get_font('text_normal_large'))
    label:SetTextColor(Theme.get_color('text'))
    label:SetContentAlignment(5)
    label:SizeToContents()
    label:SetTall(label:GetTall() + math.scale(16))
    label.Paint = function(_pnl, w, h)
      draw.RoundedBox(0, 0, 0, w, h, label_background)

      if line_color then
        draw.RoundedBox(0, 0, h - label_line_height, w, label_line_height, line_color)
      end
    end

    button.DoClick = function(btn)
      if btn:is_active() then return end

      local cur_time = CurTime()

      if self.chooser.next_click and self.chooser.next_click > cur_time then return end

      local sounds = option.sounds

      if istable(sounds) and #sounds > 0 then
        surface.PlaySound('buttons/blip1.wav')
        surface.PlaySound(table.Random(sounds))
      end

      btn:set_active(true)

      if IsValid(self.prev_button) and self.prev_button != btn then
        self.prev_button:set_active(false)
      end

      self.prev_button = btn
      self.option_id = option.id

      self.chooser.next_click = cur_time + 2
    end

    self.chooser:AddPanel(button)
  end

  self.chooser:SetVisible(true)
end

--- Stores the chosen option in the character data: its ID as option, its species and the
-- fields of its data, after taking out the fields that the data of any option of the stage
-- sets, so that nothing of an option picked before is left.
-- @param parent [Panel the character creation menu]
function PANEL:on_close(parent)
  local char_data = parent.char_data

  for _, option in ipairs(self.options or {}) do
    for key in pairs(option.data) do
      char_data[key] = nil
    end
  end

  local option = self:find_option(self.option_id)

  char_data.option = option and option.id
  char_data.species = option and option.species

  if option then
    parent:collect_data(table.Copy(option.data))
  end
end

--- Checks that an option is selected and that the local player does not have as many
-- characters of its species as it allows, unless `Characters.can_bypass_creation_limits` lets
-- them past the limit for the extra data of the creation screen.
-- @return [Boolean false when invalid, String translated error; nothing when valid]
function PANEL:on_validate()
  local option = self:find_option(self.option_id)

  if !option then
    return false, t'ui.char_create.no_species'
  end

  local parent = self:GetParent()

  if Characters.species_limit_reached(PLAYER, option.species)
  and !Characters.can_bypass_creation_limits(PLAYER, IsValid(parent) and parent.extra_data or nil) then
    return false, t'ui.char_create.species_limit'
  end
end

vgui.Register('fl_char_create_species', PANEL, 'fl_character_creation_base')
