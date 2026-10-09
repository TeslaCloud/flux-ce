--- The Classes tab of the tab menu: `fl_classes`, the list of the classes of the local
-- player's faction, and `fl_class_card`, the card of a single class.
-- Themes can draw them with the `PaintClassesMenu` and `PaintClassCard` methods; a method
-- that returns a value replaces the default look.

--- Translates an error returned by `Player:can_join_class`, translating its text arguments
-- the way notifications do.
-- @param err [String error phrase]
-- @param err_args=nil [Map arguments of the error phrase]
-- @return [String translated error]
local function translate_error(err, err_args)
  if istable(err_args) then
    for k, v in pairs(err_args) do
      if isstring(v) then
        err_args[k] = t(v)
      end
    end
  end

  local text = t(err, err_args)

  return text
end

--- The Classes page of the tab menu (`fl_classes`): a scrollable list with one
-- `fl_class_card` for every class of the local player's faction, ordered as
-- `Classes.get_faction_classes` returns them.
-- `rebuild` recreates the cards. Twice a second the cards are updated, so that the member
-- counts, the cooldown and the class of the player stay current while the tab is open, and
-- the list is rebuilt when the faction of the player has changed.
local PANEL = {}

--- Creates the scroll panel that holds the class cards.
function PANEL:Init()
  self.cards = {}

  self.scroll_panel = vgui.Create('DScrollPanel', self)
  self.scroll_panel:SetPos(0, 0)
  self.scroll_panel:SetSize(self:get_menu_size())
end

--- Draws the background and the title of the tab, unless the active theme's
-- PaintClassesMenu method does it.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintClassesMenu', self, w, h) == nil then
    local text = t'ui.classes.title'
    local font = Theme.get_font('main_menu_large')
    local text_w, text_h = util.text_size(text, font)

    DisableClipping(true)
      draw.RoundedBox(0, -4, -4, w + 8, h + 8, Color(50, 50, 50, 100))
      draw.textured_rect(
        Theme.get_material('gradient_down'),
        -4,
        -text_h - 4,
        text_w + 8,
        text_h,
        Color(50, 50, 50, 100)
      )
      draw.SimpleText(text, font, 0, -text_h - 4, color_white)
    DisableClipping(false)
  end
end

--- Updates the cards twice a second and rebuilds the list when the faction of the local
-- player is no longer the one the list was built for.
function PANEL:Think()
  self.BaseClass.Think(self)

  local cur_time = CurTime()

  if self.next_update and self.next_update > cur_time then return end

  self.next_update = cur_time + 0.5

  if self.faction_id != PLAYER:get_faction_id() then
    self:rebuild()

    return
  end

  for k, v in ipairs(self.cards) do
    if IsValid(v) then
      v:update()
    end
  end
end

--- Removes the existing cards and creates one for every class of the local player's faction.
function PANEL:rebuild()
  for k, v in ipairs(self.cards) do
    if IsValid(v) then
      v:safe_remove()
    end

    self.cards[k] = nil
  end

  local w = self:GetWide()
  local card_tall = math.scale(80)
  local margin = math.scale(4)
  local cur_y = margin

  self.faction_id = PLAYER:get_faction_id()

  for k, v in ipairs(Classes.get_faction_classes(self.faction_id)) do
    local card = vgui.Create('fl_class_card', self)
    card:SetSize(w - 8, card_tall)
    card:SetPos(4, cur_y)
    card:set_class(v)

    self.scroll_panel:AddItem(card)

    cur_y = cur_y + card_tall + margin

    table.insert(self.cards, card)
  end
end

--- Returns the size the tab menu gives this panel when it opens it.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(960), math.scale(720)
end

vgui.Register('fl_classes', PANEL, 'fl_base_panel')

--- The card of one class in the Classes tab (`fl_class_card`): the name of the class in its
-- color, its description, how many players hold it out of its limit, its wage, and a button
-- that asks the server to switch the local player to it.
-- Assign the class with `set_class`. `update` refreshes the texts and the button; when the
-- player may not switch to the class, the button is disabled and the reason is shown.
local PANEL = {}
PANEL.class_table = false
PANEL.name_text = ''
PANEL.description_text = ''
PANEL.info_text = ''
PANEL.status_text = ''

--- Creates the button that switches the local player to the class of the card.
function PANEL:Init()
  self.button = vgui.Create('fl_button', self)
  self.button:SetDrawBackground(true)
  self.button:SetFont(Theme.get_font('text_small'))
  self.button:set_centered(true)
  self.button:set_background_color(Theme.get_color('accent'))
  self.button.DoClick = function(btn)
    if self.class_table then
      Cable.send('fl_class_join', self.class_table.class_id)
    end
  end
end

--- Places the button in the top right corner of the card.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local button_w, button_h = math.scale(160), math.scale(32)

  self.button:SetSize(button_w, button_h)
  self.button:SetPos(w - button_w - math.scale(8), math.scale(8))
end

--- Draws the background of the card, a stripe in the color of the class and the texts of
-- the card, unless the active theme's PaintClassCard method does it.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintClassCard', self, w, h) == nil then
    draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background_light'))

    local class_table = self.class_table

    if !class_table then return end

    local class_color = class_table:get_color()
    local text_color = Theme.get_color('text')
    local small_font = Theme.get_font('text_small')
    local offset = math.scale(12)

    surface.SetDrawColor(class_color)
    surface.DrawRect(0, 0, math.scale(4), h)

    draw.SimpleText(self.name_text, Theme.get_font('text_normal'), offset, math.scale(4), class_color)
    draw.SimpleText(self.description_text, small_font, offset, math.scale(30), text_color)
    draw.SimpleText(self.info_text, small_font, offset, math.scale(54), text_color:darken(40))
    draw.SimpleText(
      self.status_text,
      small_font,
      w - math.scale(8),
      math.scale(54),
      text_color:darken(40),
      TEXT_ALIGN_RIGHT
    )
  end
end

--- Sets the class this card represents and fills the card in.
-- @param class_table [CharacterClass]
function PANEL:set_class(class_table)
  self.class_table = class_table

  self:update()
end

--- Returns the class this card represents.
-- @return [CharacterClass the class, or false if none has been set]
function PANEL:get_class()
  return self.class_table
end

--- Refreshes the texts of the card and the state of its button from the current members of
-- the class and from what `Player:can_join_class` says about the local player. Does nothing
-- if no class is set.
function PANEL:update()
  local class_table = self.class_table

  if !class_table then return end

  local class_id = class_table.class_id
  local limit = Classes.get_limit(class_id)
  local info = t(limit > 0 and 'ui.classes.players_limited' or 'ui.classes.players', {
    count = #Classes.get_players(class_id),
    limit = limit
  })
  local currency = Config.get('default_currency')
  local currency_data = Currencies and isstring(currency) and Currencies:find_currency(currency)

  if currency_data and class_table.wage > 0 then
    info = info..'    '..t('ui.classes.wage', {
      value = class_table.wage,
      currency = currency_data.symbol or t(currency_data.name)
    })
  end

  self.name_text = t(class_table.name)
  self.description_text = t(class_table.description)
  self.info_text = info

  if PLAYER:get_class() == class_table then
    self.status_text = ''
    self.button:set_text(t'ui.classes.current')
    self.button:set_enabled(false)

    return
  end

  local allowed, err, err_args = PLAYER:can_join_class(class_id)

  self.status_text = !allowed and err and translate_error(err, err_args) or ''
  self.button:set_text(t'ui.classes.join')
  self.button:set_enabled(allowed == true)
end

vgui.Register('fl_class_card', PANEL, 'fl_base_panel')
