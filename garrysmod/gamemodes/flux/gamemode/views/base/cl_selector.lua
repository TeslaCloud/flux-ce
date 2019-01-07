local PANEL = {}

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
end

function PANEL:SizeToContents()
	local width, height = math.max(self.text:GetWide(), ScrW() / 6), self.text:GetTall()

	self:SetSize(width + 50, height + 42 + self.list:GetTall())
end

function PANEL:set_title(text)
	self:SetTitle(text)
end

function PANEL:set_text(text)
	self.text:SetText(text)
	self.text:SizeToContents()

	self:SizeToContents()
end

function PANEL:set_value(value)
	self.list:SetValue(value)
end

function PANEL:add_choice(text, callback)
	self.list:AddChoice(text, callback)
end

vgui.Register('fl_selector', PANEL, 'DFrame')
