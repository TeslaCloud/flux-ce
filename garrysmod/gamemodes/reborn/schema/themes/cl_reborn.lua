-- Feel free to use this as a base for your own custom theme!

THEME.author = "TeslaCloud Studios"
THEME.id = "reborn"
THEME.parent = "factory"

function THEME:OnLoaded()
  self:SetColor("accent", Color(220, 100, 220))

  self:SetOption("menu_music", "sound/music/hl2_song19.mp3")
  self:SetOption("Bar_Height", 7)

  self:SetMaterial("schema_logo", "materials/flux/hl2rp/logo.png")
  self:SetMaterial("Gradient", "materials/flux/hl2rp/gradient.png")

  self:SetFont("text_bar", self:GetFont("main_font"), math.max(font.scale(14), 14), { weight = 600 })
end

function THEME:TestHook()
  return self:GetColor('accent')
end
