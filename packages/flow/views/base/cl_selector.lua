local PANEL = {}

--- Builds and shows the modal dialog: a message label and a combo box. Selecting a choice
-- runs its callback and removes the selector.
function PANEL:Init()
  self:SetTitle('')
  self:SetDraggable(false)
  self:SetBackgroundBlur(true)
  self:SetDrawOnTop(true)

  self.text = vgui.Create('DLabel', self)
  self.text:Dock(TOP)
  self.text:SetText('')
  self.text:SizeToContents()
  self.text:SetContentAlignment(5)
  self.text:SetTextColor(color_white)

  self.list = vgui.create('DComboBox', self)
  self.list:DockMargin(0, 8, 0, 0)
  self.list:Dock(TOP)
  self.list.OnSelect = function(panel, index, text, callback)
    if callback then
      callback()
    end

    self:safe_remove()
  end

  self:SizeToContents()
  self:MakePopup()
  self:DoModal()
  self:Center()
end

--- Resizes the dialog to fit the message and the combo box.
function PANEL:SizeToContents()
  local width, height = math.max(self.text:GetWide(), ScrW() / 6), self.text:GetTall()

  self:SetSize(width + 50, height + 42 + self.list:GetTall())
end

--- Sets the title of the dialog window.
-- @param text [String]
function PANEL:set_title(text)
  self:SetTitle(text)
end

--- Sets the message shown above the combo box and resizes the dialog to fit it.
-- @param text [String]
function PANEL:set_text(text)
  self.text:SetText(text)
  self.text:SizeToContents()

  self:SizeToContents()
end

--- Sets the text shown in the combo box before anything is selected.
-- @param value [String]
function PANEL:set_value(value)
  self.list:SetValue(value)
end

--- Adds a choice to the combo box. Selecting it runs the callback and removes the selector.
-- ```
-- local selector = vgui.create('fl_selector')
-- selector:set_title(t'ui.admin.selector.title')
-- selector:set_text(t'ui.admin.selector.message')
-- selector:set_value(t'ui.admin.selector.roles')
--
-- for k, v in pairs(Bolt:get_roles()) do
--   selector:add_choice(v.name, function()
--     Cable.send('fl_bolt_set_role', self.player, v.role_id)
--   end)
-- end
-- ```
-- @param text [String label of the choice]
-- @param callback=nil [Function called without arguments when the choice is selected]
function PANEL:add_choice(text, callback)
  self.list:AddChoice(text, callback)
end

vgui.Register('fl_selector', PANEL, 'DFrame')
