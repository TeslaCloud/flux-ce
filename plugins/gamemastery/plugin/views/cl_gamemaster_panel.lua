--- The gamemaster panel of the tab menu and the cards of the pool characters in it.

local drop_name = 'fl_gm_character'

--- Places the pool character of a dropped card in the world, where the cursor points.
-- @param _receiver [Panel the panel the card was dropped on]
-- @param panels [List<Panel> the dragged panels]
-- @param is_dropped [Boolean true when the card was dropped, false while it hovers]
local function drop_on_world(_receiver, panels, is_dropped)
  if !is_dropped then return end

  local card = panels[1]
  local char_data = IsValid(card) and card.char_data

  if !istable(char_data) then return end

  Gamemastery.request_spawn(char_data.id, gui.ScreenToVector(gui.MouseX(), gui.MouseY()))
end

--- Ignores cards that are dropped back onto the gamemaster panel.
-- @param _receiver [Panel]
-- @param _panels [List<Panel>]
-- @param _is_dropped [Boolean]
local function ignore_drop(_receiver, _panels, _is_dropped)
end

--- The gamemaster panel (`fl_gamemaster_panel`): a scrollable row of cards, one for every
-- pool character, a button that releases the pool character the local player plays and a
-- hint. While the panel is open the tab menu around it takes the cards: a card dropped
-- anywhere outside of the panel places its character in the world where the cursor points.
-- The panel rebuilds itself whenever the pool arrives from the server.
local PANEL = {}

--- Creates the title, the hint, the release button and the card row, makes the tab menu
-- take dropped cards and asks the server for the pool.
function PANEL:Init()
  local font = Theme.get_font('main_menu_normal')

  self.title_label = vgui.Create('DLabel', self)
  self.title_label:SetFont(Theme.get_font('main_menu_titles'))
  self.title_label:SetText(t'ui.gamemastery.title')
  self.title_label:SetTextColor(Theme.get_color('text'))
  self.title_label:SizeToContents()

  self.hint_label = vgui.Create('DLabel', self)
  self.hint_label:SetFont(Theme.get_font('text_small'))
  self.hint_label:SetText(t'ui.gamemastery.hint')
  self.hint_label:SetTextColor(Theme.get_color('text_muted'))
  self.hint_label:SizeToContents()

  self.empty_label = vgui.Create('DLabel', self)
  self.empty_label:SetFont(font)
  self.empty_label:SetText(t'ui.gamemastery.empty')
  self.empty_label:SetTextColor(Theme.get_color('text_muted'))
  self.empty_label:SizeToContents()
  self.empty_label:SetVisible(false)

  self.release = vgui.Create('fl_button', self)
  self.release:SetFont(font)
  self.release:SetTitle(t'ui.gamemastery.release')
  self.release:SetDrawBackground(true)
  self.release:set_draw_outline(true)
  self.release:set_icon('fa-sign-out-alt')
  self.release:set_icon_size(math.scale(16))
  self.release:set_centered(true)
  self.release:SetVisible(false)
  self.release.DoClick = function(_btn)
    surface.PlaySound(Theme.get_sound('button_click_success_sound'))

    Gamemastery.request_release()
  end

  self.list = vgui.Create('fl_horizontalbar', self)
  self.list:SetOverlap(math.scale(12))

  self:Receiver(drop_name, ignore_drop)

  local menu = self:GetParent()

  if IsValid(menu) then
    menu:Receiver(drop_name, drop_on_world)

    self.drop_target = menu
  end

  --- Rebuilds the cards every time the pool arrives from the server.
  hook.Add('OnGamemasterPoolReceived', self, self.rebuild)

  Gamemastery.request_pool()
end

--- Stops the tab menu from taking dropped cards once the panel is gone.
function PANEL:OnRemove()
  local target = self.drop_target

  if IsValid(target) and istable(target.m_ReceiverSlot) then
    target.m_ReceiverSlot[drop_name] = nil
  end
end

--- Returns the size the tab menu gives this panel: 1400 by 600 at 1080p, kept within the
-- screen below the button bar of the menu.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.min(math.scale(1400), ScrW() - math.scale(32)), math.min(math.scale(600), ScrH() - math.scale(96))
end

--- Positions the title, the hint, the release button, the card row and the text shown
-- when the pool is empty.
-- @param w [Number]
-- @param h [Number]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(16)
  local button_height = Theme.get_option('menu_sidebar_button_height')

  self.title_label:SetPos(padding, padding)
  self.hint_label:SetPos(padding, padding + self.title_label:GetTall() + math.scale(4))

  self.release:SetSize(math.scale(200), button_height)
  self.release:SetPos(w - self.release:GetWide() - padding, padding)

  local list_y = math.max(self.hint_label.y + self.hint_label:GetTall(), self.release.y + button_height) + padding

  self.list:SetPos(padding, list_y)
  self.list:SetSize(w - padding * 2, h - list_y - padding)

  self.empty_label:SetPos(w * 0.5 - self.empty_label:GetWide() * 0.5, h * 0.5 - self.empty_label:GetTall() * 0.5)
end

--- Recreates a card for every pool character, shows the release button while the local
-- player plays one and the empty text when there are none.
function PANEL:rebuild()
  if !IsValid(self.list) then return end

  self:InvalidateLayout(true)
  self.list:Clear()

  local pool = Gamemastery.get_pool()
  local card_w = math.max(math.scale(180), self.list:GetWide() * 0.15)
  local possessing = false

  for _k, v in ipairs(pool) do
    local card = vgui.Create('fl_gamemaster_card', self)
    card:SetSize(card_w, self.list:GetTall())
    card:set_character(v)

    self.list:AddPanel(card)

    if Gamemastery.is_possessing(v) then
      possessing = true
    end
  end

  self.release:SetVisible(possessing)
  self.empty_label:SetVisible(#pool == 0)
end

vgui.Register('fl_gamemaster_panel', PANEL, 'fl_base_panel')

--- A pool character in the gamemaster panel (`fl_gamemaster_card`): its model, a button that
-- possesses it (or releases it when the local player plays it, or says who plays it), a
-- button that deletes it once its name has been typed to confirm, and a marker when it
-- stands in the world. The card can be dragged out of the panel onto the world.
local PANEL = {}

--- Creates the model preview, the buttons and makes the card draggable.
function PANEL:Init()
  self:SetPaintBackground(false)
  self:Droppable(drop_name)

  self.model = vgui.Create('DModelPanel', self)
  self.model:SetFOV(30)
  self.model:SetCamPos(Vector(80, 0, 50))
  self.model:SetLookAt(Vector(0, 0, 37))
  self.model:SetAnimated(true)
  self.model:SetDragParent(self)
  self.model.LayoutEntity = function(_entity) end

  self.possess = vgui.Create('fl_button', self)
  self.possess:SetFont(Theme.get_font('main_menu_normal'))
  self.possess:SetTitle(t'ui.gamemastery.possess')
  self.possess:SetDrawBackground(true)
  self.possess:set_active(true)
  self.possess:set_icon('fa-ghost')
  self.possess:set_icon_size(math.scale(16))
  self.possess:set_centered(true)
  self.possess.DoClick = function(_btn)
    local cur_time = CurTime()

    if self.next_click and self.next_click > cur_time then return end

    self.next_click = cur_time + 1

    if Gamemastery.is_possessing(self.char_data) then
      Gamemastery.request_release()
    else
      Gamemastery.request_possess(self.char_data.id)
    end
  end

  self.delete = vgui.Create('fl_button', self)
  self.delete:SetFont(Theme.get_font('main_menu_normal'))
  self.delete:SetDrawBackground(true)
  self.delete:set_draw_outline(true)
  self.delete:set_background_color(Theme.get_color('surface_raised'))
  self.delete:set_text_color(Theme.get_color('danger'))
  self.delete:set_icon('fa-trash')
  self.delete:set_icon_size(math.scale(18))
  self.delete:set_centered(true)
  self.delete:SetTooltip(t'ui.gamemastery.delete')
  self.delete.DoClick = function(_btn)
    local name = self.char_data.name

    surface.PlaySound('vo/npc/male01/answer37.wav')

    Derma_StringRequest(
      t'ui.gamemastery.delete_title',
      t('ui.gamemastery.delete_message', { name = name }),
      '',
      function(text)
        if text == name then
          Gamemastery.request_delete(self.char_data.id)
        end
      end,
      nil,
      t'ui.gamemastery.delete'
    )
  end
end

--- Draws the card through the theme's PaintCharPanel hook.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  if self:IsVisible() then
    Theme.hook('PaintCharPanel', self, w, h)
  end
end

--- Draws the marker of a character that stands in the world under the name.
-- @param w [Number]
-- @param _h [Number]
function PANEL:PaintOver(w, _h)
  if !istable(self.char_data) or !self.char_data.in_world then return end

  local text, font = t'ui.gamemastery.in_world', Theme.get_font('text_small')
  local text_w, text_h = util.text_size(text, font)
  local x, y = w * 0.5 - (text_w + text_h + math.scale(6)) * 0.5, math.scale(44)
  local color = Theme.get_color('accent')

  FontAwesome:draw('fa-map-marker-alt', x, y, text_h, color)
  draw.SimpleText(text, font, x + text_h + math.scale(6), y, color)
end

--- Positions the model preview and the buttons. The possess button takes the whole width
-- when there is no delete button next to it.
-- @param w [Number]
-- @param h [Number]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)
  local header = math.scale(40)
  local button_height = Theme.get_option('menu_sidebar_button_height')
  local button_y = h - button_height - padding
  local gap = math.scale(4)

  self.model:SetPos(padding, header)
  self.model:SetSize(w - padding * 2, button_y - header - padding)

  if self.delete:IsVisible() then
    local delete_w = math.floor(w / 3) - padding

    self.possess:SetPos(padding, button_y)
    self.possess:SetSize(w - delete_w - padding * 2 - gap, button_height)

    self.delete:SetPos(w - delete_w - padding, button_y)
    self.delete:SetSize(delete_w, button_height)
  else
    self.possess:SetPos(padding, button_y)
    self.possess:SetSize(w - padding * 2, button_height)
  end
end

--- Sets the pool character shown by the card. A character the local player plays gets a
-- release button, one somebody else plays a disabled button with their name, and a banned
-- one a disabled button that says so; the delete button is hidden while anybody plays the
-- character.
-- @param char_data [Map an entry of the pool list]
function PANEL:set_character(char_data)
  self.char_data = char_data

  self.model:SetModel(char_data.model)

  local entity = self.model:GetEntity()

  if IsValid(entity) then
    entity:SetSequence(entity:idle_animation())
    entity:SetSkin(char_data.skin or 0)
  end

  self:SetTooltip(char_data.phys_desc)

  if Gamemastery.is_possessing(char_data) then
    self.possess:SetTitle(t'ui.gamemastery.release')
    self.possess:set_icon('fa-sign-out-alt')
    self.delete:SetVisible(false)
  elseif char_data.possessed_by then
    self:disable_possess(t('ui.gamemastery.taken', { name = char_data.possessed_by }), 'fa-user-lock')
    self.delete:SetVisible(false)
  elseif char_data.banned then
    self.model:SetColor(Color(80, 80, 80))

    self:disable_possess(t'ui.gamemastery.banned', 'fa-ban')
  end

  self:InvalidateLayout()
end

--- Turns the possess button into a disabled notice.
-- @param text [String the text of the button]
-- @param icon [String FontAwesome ID of its icon]
function PANEL:disable_possess(text, icon)
  self.possess:SetTitle(text)
  self.possess:set_icon(icon)
  self.possess:set_active(false)
  self.possess:set_draw_outline(true)
  self.possess:set_background_color(Theme.get_color('surface_raised'))
  self.possess:set_enabled(false)
  self.possess:set_text_color(Theme.get_color('danger'))
end

vgui.Register('fl_gamemaster_card', PANEL, 'DPanel')
