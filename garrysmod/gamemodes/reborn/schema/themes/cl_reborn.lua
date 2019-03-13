-- Feel free to use this as a base for your own custom theme!

THEME.author  = "TeslaCloud Studios"
THEME.id      = "reborn"
THEME.parent  = "factory"

function THEME:OnLoaded()
  self:set_color("accent", Color(220, 100, 220))

  self:set_option("menu_music", "sound/music/hl2_song19.mp3")
  self:set_option("Bar_Height", 7)

  self:set_material("schema_logo", "materials/flux/hl2rp/logo.png")
  self:set_material("Gradient", "materials/flux/hl2rp/gradient.png")

  self:set_font("text_bar", self:get_font("main_font"), math.max(Font.scale(14), 14), { weight = 600 })
end

function THEME:TestHook()
  return self:get_color('accent')
end
