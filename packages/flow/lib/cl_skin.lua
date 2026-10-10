--- The 'Flux' Derma skin, which Flux makes the default skin of all Derma panels. It is a copy
-- of the default GWEN skin of Garry's Mod, defined under the name 'Flux' as a base for themes:
-- `Theme.set_derma_skin` copies the `skin` table of the active theme over it.

-- Default GWEN skin copy-pasta.

local set_draw_color = surface.SetDrawColor
local draw_rect      = surface.DrawRect
local shade_color    = Color(0, 0, 0, 100)
local disabled_tint  = Color(255, 255, 255, 50)

-- Pixel sizes that the paint functions hardcode are scaled with the screen like the stock
-- Derma panels (see cl_derma_scale.lua), which loads after this file.
local function scale(size)
  return DermaScale and DermaScale.scale(size) or size
end

SKIN                                    = {}

SKIN.print_name                         = 'Flux Skin'
SKIN.Author                             = 'TeslaCloud Studios'
SKIN.DermaVersion                       = 1
SKIN.GwenTexture                        = Material('gwenskin/GModDefault.png')

SKIN.bg_color                           = Color(101, 100, 105, 255)
SKIN.bg_color_sleep                     = Color(70, 70, 70, 255)
SKIN.bg_color_dark                      = Color(55, 57, 61, 255)
SKIN.bg_color_bright                    = Color(220, 220, 220, 255)
SKIN.frame_border                       = Color(50, 50, 50, 255)

SKIN.fontFrame                          = 'DermaDefault'

SKIN.control_color                      = Color(120, 120, 120, 255)
SKIN.control_color_highlight            = Color(150, 150, 150, 255)
SKIN.control_color_active               = Color(110, 150, 250, 255)
SKIN.control_color_bright               = Color(255, 200, 100, 255)
SKIN.control_color_dark                 = Color(100, 100, 100, 255)

SKIN.bg_alt1                            = Color(50, 50, 50, 255)
SKIN.bg_alt2                            = Color(55, 55, 55, 255)

SKIN.listview_hover                     = Color(70, 70, 70, 255)
SKIN.listview_selected                  = Color(100, 170, 220, 255)

SKIN.text_bright                        = Color(255, 255, 255, 255)
SKIN.text_normal                        = Color(180, 180, 180, 255)
SKIN.text_dark                          = Color(20, 20, 20, 255)
SKIN.text_highlight                     = Color(255, 20, 20, 255)

SKIN.texGradientUp                      = Material('gui/gradient_up')
SKIN.texGradientDown                    = Material('gui/gradient_down')

SKIN.combobox_selected                  = SKIN.listview_selected

SKIN.panel_transback                    = Color(255, 255, 255, 50)
SKIN.tooltip                            = Color(255, 245, 175, 255)

SKIN.colPropertySheet                   = Color(170, 170, 170, 255)
SKIN.colTab                             = SKIN.colPropertySheet
SKIN.colTabInactive                     = Color(140, 140, 140, 255)
SKIN.colTabShadow                       = Color(0, 0, 0, 170)
SKIN.colTabText                         = Color(255, 255, 255, 255)
SKIN.colTabTextInactive                 = Color(0, 0, 0, 200)
SKIN.fontTab                            = 'DermaDefault'

SKIN.colCollapsibleCategory             = Color(255, 255, 255, 20)

SKIN.colCategoryText                    = Color(255, 255, 255, 255)
SKIN.colCategoryTextInactive            = Color(200, 200, 200, 255)
SKIN.fontCategoryHeader                 = 'TabLarge'

SKIN.colNumberWangBG                    = Color(255, 240, 150, 255)
SKIN.colTextEntryBG                     = Color(240, 240, 240, 255)
SKIN.colTextEntryBorder                 = Color(20, 20, 20, 255)
SKIN.colTextEntryText                   = Color(20, 20, 20, 255)
SKIN.colTextEntryTextHighlight          = Color(20, 200, 250, 255)
SKIN.colTextEntryTextCursor             = Color(0, 0, 100, 255)

SKIN.colMenuBG                          = Color(255, 255, 255, 200)
SKIN.colMenuBorder                      = Color(0, 0, 0, 200)

SKIN.colButtonText                      = Color(255, 255, 255, 255)
SKIN.colButtonTextDisabled              = Color(255, 255, 255, 55)
SKIN.colButtonBorder                    = Color(20, 20, 20, 255)
SKIN.colButtonBorderHighlight           = Color(255, 255, 255, 50)
SKIN.colButtonBorderShadow              = Color(0, 0, 0, 100)

SKIN.tex                                = {}

SKIN.tex.Selection                      = GWEN.CreateTextureBorder(384, 32, 31, 31, 4, 4, 4, 4)

SKIN.tex.Panels                         = {}
SKIN.tex.Panels.Normal                  = GWEN.CreateTextureBorder(256, 0, 63, 63, 16, 16, 16, 16)
SKIN.tex.Panels.Bright                  = GWEN.CreateTextureBorder(256 + 64, 0, 63, 63, 16, 16, 16, 16)
SKIN.tex.Panels.Dark                    = GWEN.CreateTextureBorder(256, 64, 63, 63, 16, 16, 16, 16)
SKIN.tex.Panels.Highlight               = GWEN.CreateTextureBorder(256 + 64, 64, 63, 63, 16, 16, 16, 16)

SKIN.tex.Button                         = GWEN.CreateTextureBorder(480, 0, 31, 31, 8, 8, 8, 8)
SKIN.tex.Button_Hovered                 = GWEN.CreateTextureBorder(480, 32, 31, 31, 8, 8, 8, 8)
SKIN.tex.Button_Dead                    = GWEN.CreateTextureBorder(480, 64, 31, 31, 8, 8, 8, 8)
SKIN.tex.Button_Down                    = GWEN.CreateTextureBorder(480, 96, 31, 31, 8, 8, 8, 8)
SKIN.tex.Shadow                         = GWEN.CreateTextureBorder(448, 0, 31, 31, 8, 8, 8, 8)

SKIN.tex.Tree                           = GWEN.CreateTextureBorder(256, 128, 127, 127, 16, 16, 16, 16)
SKIN.tex.Checkbox_Checked               = GWEN.CreateTextureNormal(448, 32, 15, 15)
SKIN.tex.Checkbox                       = GWEN.CreateTextureNormal(464, 32, 15, 15)
SKIN.tex.CheckboxD_Checked              = GWEN.CreateTextureNormal(448, 48, 15, 15)
SKIN.tex.CheckboxD                      = GWEN.CreateTextureNormal(464, 48, 15, 15)
SKIN.tex.RadioButton_Checked            = GWEN.CreateTextureNormal(448, 64, 15, 15)
SKIN.tex.RadioButton                    = GWEN.CreateTextureNormal(464, 64, 15, 15)
SKIN.tex.RadioButtonD_Checked           = GWEN.CreateTextureNormal(448, 80, 15, 15)
SKIN.tex.RadioButtonD                   = GWEN.CreateTextureNormal(464, 80, 15, 15)
SKIN.tex.TreePlus                       = GWEN.CreateTextureNormal(448, 96, 15, 15)
SKIN.tex.TreeMinus                      = GWEN.CreateTextureNormal(464, 96, 15, 15)
SKIN.tex.TextBox                        = GWEN.CreateTextureBorder(0, 150, 127, 21, 4, 4, 4, 4)
SKIN.tex.TextBox_Focus                  = GWEN.CreateTextureBorder(0, 172, 127, 21, 4, 4, 4, 4)
SKIN.tex.TextBox_Disabled               = GWEN.CreateTextureBorder(0, 194, 127, 21, 4, 4, 4, 4)
SKIN.tex.MenuBG_Column                  = GWEN.CreateTextureBorder(128, 128, 127, 63, 24, 8, 8, 8)
SKIN.tex.MenuBG                         = GWEN.CreateTextureBorder(128, 192, 127, 63, 8, 8, 8, 8)
SKIN.tex.MenuBG_Hover                   = GWEN.CreateTextureBorder(128, 256, 127, 31, 8, 8, 8, 8)
SKIN.tex.MenuBG_Spacer                  = GWEN.CreateTextureNormal(128, 288, 127, 3)
SKIN.tex.Menu_Strip                     = GWEN.CreateTextureBorder(0, 128, 127, 21, 8, 8, 8, 8)
SKIN.tex.Menu_Check                     = GWEN.CreateTextureNormal(448, 112, 15, 15)
SKIN.tex.Tab_Control                    = GWEN.CreateTextureBorder(0, 256, 127, 127, 8, 8, 8, 8)
SKIN.tex.TabB_Active                    = GWEN.CreateTextureBorder(0, 416, 63, 31, 8, 8, 8, 8)
SKIN.tex.TabB_Inactive                  = GWEN.CreateTextureBorder(128, 416, 63, 31, 8, 8, 8, 8)
SKIN.tex.TabT_Active                    = GWEN.CreateTextureBorder(0, 384, 63, 31, 8, 8, 8, 8)
SKIN.tex.TabT_Inactive                  = GWEN.CreateTextureBorder(128, 384, 63, 31, 8, 8, 8, 8)
SKIN.tex.TabL_Active                    = GWEN.CreateTextureBorder(64, 384, 31, 63, 8, 8, 8, 8)
SKIN.tex.TabL_Inactive                  = GWEN.CreateTextureBorder(64 + 128, 384, 31, 63, 8, 8, 8, 8)
SKIN.tex.TabR_Active                    = GWEN.CreateTextureBorder(96, 384, 31, 63, 8, 8, 8, 8)
SKIN.tex.TabR_Inactive                  = GWEN.CreateTextureBorder(96 + 128, 384, 31, 63, 8, 8, 8, 8)
SKIN.tex.Tab_Bar                        = GWEN.CreateTextureBorder(128, 352, 127, 31, 4, 4, 4, 4)

SKIN.tex.Window                         = {}

SKIN.tex.Window.Normal                  = GWEN.CreateTextureBorder(0, 0, 127, 127, 8, 32, 8, 8)
SKIN.tex.Window.Inactive                = GWEN.CreateTextureBorder(128, 0, 127, 127, 8, 32, 8, 8)

SKIN.tex.Window.Close                   = GWEN.CreateTextureNormal(32, 448, 31, 31)
SKIN.tex.Window.Close_Hover             = GWEN.CreateTextureNormal(64, 448, 31, 31)
SKIN.tex.Window.Close_Down              = GWEN.CreateTextureNormal(96, 448, 31, 31)

SKIN.tex.Window.Maxi                    = GWEN.CreateTextureNormal(32 + 96 * 2, 448, 31, 31)
SKIN.tex.Window.Maxi_Hover              = GWEN.CreateTextureNormal(64 + 96 * 2, 448, 31, 31)
SKIN.tex.Window.Maxi_Down               = GWEN.CreateTextureNormal(96 + 96 * 2, 448, 31, 31)

SKIN.tex.Window.Restore                 = GWEN.CreateTextureNormal(32 + 96 * 2, 448 + 32, 31, 31)
SKIN.tex.Window.Restore_Hover           = GWEN.CreateTextureNormal(64 + 96 * 2, 448 + 32, 31, 31)
SKIN.tex.Window.Restore_Down            = GWEN.CreateTextureNormal(96 + 96 * 2, 448 + 32, 31, 31)

SKIN.tex.Window.Mini                    = GWEN.CreateTextureNormal(32 + 96, 448, 31, 31)
SKIN.tex.Window.Mini_Hover              = GWEN.CreateTextureNormal(64 + 96, 448, 31, 31)
SKIN.tex.Window.Mini_Down               = GWEN.CreateTextureNormal(96 + 96, 448, 31, 31)

SKIN.tex.Scroller                       = {}
SKIN.tex.Scroller.TrackV                = GWEN.CreateTextureBorder(384, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonV_Normal        = GWEN.CreateTextureBorder(384 + 16, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonV_Hover         = GWEN.CreateTextureBorder(384 + 32, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonV_Down          = GWEN.CreateTextureBorder(384 + 48, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonV_Disabled      = GWEN.CreateTextureBorder(384 + 64, 208, 15, 127, 4, 4, 4, 4)

SKIN.tex.Scroller.TrackH                = GWEN.CreateTextureBorder(384, 128, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonH_Normal        = GWEN.CreateTextureBorder(384, 128 + 16, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonH_Hover         = GWEN.CreateTextureBorder(384, 128 + 32, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonH_Down          = GWEN.CreateTextureBorder(384, 128 + 48, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonH_Disabled      = GWEN.CreateTextureBorder(384, 128 + 64, 127, 15, 4, 4, 4, 4)

SKIN.tex.Scroller.LeftButton_Normal     = GWEN.CreateTextureBorder(464, 208, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.LeftButton_Hover      = GWEN.CreateTextureBorder(480, 208, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.LeftButton_Down       = GWEN.CreateTextureBorder(464, 272, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.LeftButton_Disabled   = GWEN.CreateTextureBorder(480 + 48, 272, 15, 15, 2, 2, 2, 2)

SKIN.tex.Scroller.UpButton_Normal       = GWEN.CreateTextureBorder(464, 208 + 16, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.UpButton_Hover        = GWEN.CreateTextureBorder(480, 208 + 16, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.UpButton_Down         = GWEN.CreateTextureBorder(464, 272 + 16, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.UpButton_Disabled     = GWEN.CreateTextureBorder(480 + 48, 272 + 16, 15, 15, 2, 2, 2, 2)

SKIN.tex.Scroller.RightButton_Normal    = GWEN.CreateTextureBorder(464, 208 + 32, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.RightButton_Hover     = GWEN.CreateTextureBorder(480, 208 + 32, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.RightButton_Down      = GWEN.CreateTextureBorder(464, 272 + 32, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.RightButton_Disabled  = GWEN.CreateTextureBorder(480 + 48, 272 + 32, 15, 15, 2, 2, 2, 2)

SKIN.tex.Scroller.DownButton_Normal     = GWEN.CreateTextureBorder(464, 208 + 48, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.DownButton_Hover      = GWEN.CreateTextureBorder(480, 208 + 48, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.DownButton_Down       = GWEN.CreateTextureBorder(464, 272 + 48, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.DownButton_Disabled   = GWEN.CreateTextureBorder(480 + 48, 272 + 48, 15, 15, 2, 2, 2, 2)

SKIN.tex.Menu                           = {}
SKIN.tex.Menu.RightArrow                = GWEN.CreateTextureNormal(464, 112, 15, 15)

SKIN.tex.Input                          = {}

SKIN.tex.Input.ComboBox                 = {}
SKIN.tex.Input.ComboBox.Normal          = GWEN.CreateTextureBorder(384, 336, 127, 31, 8, 8, 32, 8)
SKIN.tex.Input.ComboBox.Hover           = GWEN.CreateTextureBorder(384, 336 + 32, 127, 31, 8, 8, 32, 8)
SKIN.tex.Input.ComboBox.Down            = GWEN.CreateTextureBorder(384, 336 + 64, 127, 31, 8, 8, 32, 8)
SKIN.tex.Input.ComboBox.Disabled        = GWEN.CreateTextureBorder(384, 336 + 96, 127, 31, 8, 8, 32, 8)

SKIN.tex.Input.ComboBox.Button          = {}
SKIN.tex.Input.ComboBox.Button.Normal   = GWEN.CreateTextureNormal(496, 272, 15, 15)
SKIN.tex.Input.ComboBox.Button.Hover    = GWEN.CreateTextureNormal(496, 272 + 16, 15, 15)
SKIN.tex.Input.ComboBox.Button.Down     = GWEN.CreateTextureNormal(496, 272 + 32, 15, 15)
SKIN.tex.Input.ComboBox.Button.Disabled = GWEN.CreateTextureNormal(496, 272 + 48, 15, 15)

SKIN.tex.Input.UpDown                   = {}
SKIN.tex.Input.UpDown.Up                = {}
SKIN.tex.Input.UpDown.Up.Normal         = GWEN.CreateTextureCentered(384, 112, 7, 7)
SKIN.tex.Input.UpDown.Up.Hover          = GWEN.CreateTextureCentered(384 + 8, 112, 7, 7)
SKIN.tex.Input.UpDown.Up.Down           = GWEN.CreateTextureCentered(384 + 16, 112, 7, 7)
SKIN.tex.Input.UpDown.Up.Disabled       = GWEN.CreateTextureCentered(384 + 24, 112, 7, 7)

SKIN.tex.Input.UpDown.Down              = {}
SKIN.tex.Input.UpDown.Down.Normal       = GWEN.CreateTextureCentered(384, 120, 7, 7)
SKIN.tex.Input.UpDown.Down.Hover        = GWEN.CreateTextureCentered(384 + 8, 120, 7, 7)
SKIN.tex.Input.UpDown.Down.Down         = GWEN.CreateTextureCentered(384 + 16, 120, 7, 7)
SKIN.tex.Input.UpDown.Down.Disabled     = GWEN.CreateTextureCentered(384 + 24, 120, 7, 7)

SKIN.tex.Input.Slider                   = {}
SKIN.tex.Input.Slider.H                 = {}
SKIN.tex.Input.Slider.H.Normal          = GWEN.CreateTextureNormal(416, 32, 15, 15)
SKIN.tex.Input.Slider.H.Hover           = GWEN.CreateTextureNormal(416, 32 + 16, 15, 15)
SKIN.tex.Input.Slider.H.Down            = GWEN.CreateTextureNormal(416, 32 + 32, 15, 15)
SKIN.tex.Input.Slider.H.Disabled        = GWEN.CreateTextureNormal(416, 32 + 48, 15, 15)

SKIN.tex.Input.Slider.V                 = {}
SKIN.tex.Input.Slider.V.Normal          = GWEN.CreateTextureNormal(416 + 16, 32, 15, 15)
SKIN.tex.Input.Slider.V.Hover           = GWEN.CreateTextureNormal(416 + 16, 32 + 16, 15, 15)
SKIN.tex.Input.Slider.V.Down            = GWEN.CreateTextureNormal(416 + 16, 32 + 32, 15, 15)
SKIN.tex.Input.Slider.V.Disabled        = GWEN.CreateTextureNormal(416 + 16, 32 + 48, 15, 15)

SKIN.tex.Input.ListBox                  = {}
SKIN.tex.Input.ListBox.Background       = GWEN.CreateTextureBorder(256, 256, 63, 127, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.Hovered          = GWEN.CreateTextureBorder(320, 320, 31, 31, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.EvenLine         = GWEN.CreateTextureBorder(352, 256, 31, 31, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.OddLine          = GWEN.CreateTextureBorder(352, 288, 31, 31, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.EvenLineSelected = GWEN.CreateTextureBorder(320, 256, 31, 31, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.OddLineSelected  = GWEN.CreateTextureBorder(320, 288, 31, 31, 8, 8, 8, 8)

SKIN.tex.ProgressBar                    = {}
SKIN.tex.ProgressBar.Back               = GWEN.CreateTextureBorder(384, 0, 31, 31, 8, 8, 8, 8)
SKIN.tex.ProgressBar.Front              = GWEN.CreateTextureBorder(384 + 32, 0, 31, 31, 8, 8, 8, 8)

SKIN.tex.categoryList                   = {}
SKIN.tex.categoryList.Outer             = GWEN.CreateTextureBorder(256, 384, 63, 63, 8, 8, 8, 8)
SKIN.tex.categoryList.Inner             = GWEN.CreateTextureBorder(320, 384, 63, 63, 8, 21, 8, 8)
SKIN.tex.categoryList.Header            = GWEN.CreateTextureBorder(320, 352, 63, 31, 8, 8, 8, 8)

SKIN.tex.Tooltip                        = GWEN.CreateTextureBorder(384, 64, 31, 31, 8, 8, 8, 8)

SKIN.Colours                            = {}

SKIN.Colours.Window                     = {}
SKIN.Colours.Window.TitleActive         = GWEN.TextureColor(4 + 8 * 0, 508)
SKIN.Colours.Window.TitleInactive       = GWEN.TextureColor(4 + 8 * 1, 508)

SKIN.Colours.Button                     = {}
SKIN.Colours.Button.Normal              = GWEN.TextureColor(4 + 8 * 2, 508)
SKIN.Colours.Button.Hover               = GWEN.TextureColor(4 + 8 * 3, 508)
SKIN.Colours.Button.Down                = GWEN.TextureColor(4 + 8 * 2, 500)
SKIN.Colours.Button.Disabled            = GWEN.TextureColor(4 + 8 * 3, 500)

SKIN.Colours.Tab                        = {}
SKIN.Colours.Tab.Active                 = {}
SKIN.Colours.Tab.Active.Normal          = GWEN.TextureColor(4 + 8 * 4, 508)
SKIN.Colours.Tab.Active.Hover           = GWEN.TextureColor(4 + 8 * 5, 508)
SKIN.Colours.Tab.Active.Down            = GWEN.TextureColor(4 + 8 * 4, 500)
SKIN.Colours.Tab.Active.Disabled        = GWEN.TextureColor(4 + 8 * 5, 500)

SKIN.Colours.Tab.Inactive               = {}
SKIN.Colours.Tab.Inactive.Normal        = GWEN.TextureColor(4 + 8 * 6, 508)
SKIN.Colours.Tab.Inactive.Hover         = GWEN.TextureColor(4 + 8 * 7, 508)
SKIN.Colours.Tab.Inactive.Down          = GWEN.TextureColor(4 + 8 * 6, 500)
SKIN.Colours.Tab.Inactive.Disabled      = GWEN.TextureColor(4 + 8 * 7, 500)

SKIN.Colours.Label                      = {}
SKIN.Colours.Label.Default              = GWEN.TextureColor(4 + 8 * 8, 508)
SKIN.Colours.Label.Bright               = GWEN.TextureColor(4 + 8 * 9, 508)
SKIN.Colours.Label.Dark                 = GWEN.TextureColor(4 + 8 * 8, 500)
SKIN.Colours.Label.Highlight            = GWEN.TextureColor(4 + 8 * 9, 500)

SKIN.Colours.Tree                       = {}
SKIN.Colours.Tree.Lines                 = GWEN.TextureColor(4 + 8 * 10, 508) ---- !!!
SKIN.Colours.Tree.Normal                = GWEN.TextureColor(4 + 8 * 11, 508)
SKIN.Colours.Tree.Hover                 = GWEN.TextureColor(4 + 8 * 10, 500)
SKIN.Colours.Tree.Selected              = GWEN.TextureColor(4 + 8 * 11, 500)

SKIN.Colours.Properties                 = {}
SKIN.Colours.Properties.Line_Normal     = GWEN.TextureColor(4 + 8 * 12, 508)
SKIN.Colours.Properties.Line_Selected   = GWEN.TextureColor(4 + 8 * 13, 508)
SKIN.Colours.Properties.Line_Hover      = GWEN.TextureColor(4 + 8 * 12, 500)
SKIN.Colours.Properties.Title           = GWEN.TextureColor(4 + 8 * 13, 500)
SKIN.Colours.Properties.Column_Normal   = GWEN.TextureColor(4 + 8 * 14, 508)
SKIN.Colours.Properties.Column_Selected = GWEN.TextureColor(4 + 8 * 15, 508)
SKIN.Colours.Properties.Column_Hover    = GWEN.TextureColor(4 + 8 * 14, 500)
SKIN.Colours.Properties.Border          = GWEN.TextureColor(4 + 8 * 15, 500)
SKIN.Colours.Properties.Label_Normal    = GWEN.TextureColor(4 + 8 * 16, 508)
SKIN.Colours.Properties.Label_Selected  = GWEN.TextureColor(4 + 8 * 17, 508)
SKIN.Colours.Properties.Label_Hover     = GWEN.TextureColor(4 + 8 * 16, 500)

SKIN.Colours.Category                   = {}
SKIN.Colours.Category.Header            = GWEN.TextureColor(4 + 8 * 18, 500)
SKIN.Colours.Category.Header_Closed     = GWEN.TextureColor(4 + 8 * 19, 500)

SKIN.Colours.Category.Line                    = {}
SKIN.Colours.Category.Line.Text               = GWEN.TextureColor(4 + 8 * 20, 508)
SKIN.Colours.Category.Line.Text_Hover         = GWEN.TextureColor(4 + 8 * 21, 508)
SKIN.Colours.Category.Line.Text_Selected      = GWEN.TextureColor(4 + 8 * 20, 500)
SKIN.Colours.Category.Line.Button             = GWEN.TextureColor(4 + 8 * 21, 500)
SKIN.Colours.Category.Line.Button_Hover       = GWEN.TextureColor(4 + 8 * 22, 508)
SKIN.Colours.Category.Line.Button_Selected    = GWEN.TextureColor(4 + 8 * 23, 508)

SKIN.Colours.Category.LineAlt                 = {}
SKIN.Colours.Category.LineAlt.Text            = GWEN.TextureColor(4 + 8 * 22, 500)
SKIN.Colours.Category.LineAlt.Text_Hover      = GWEN.TextureColor(4 + 8 * 23, 500)
SKIN.Colours.Category.LineAlt.Text_Selected   = GWEN.TextureColor(4 + 8 * 24, 508)
SKIN.Colours.Category.LineAlt.Button          = GWEN.TextureColor(4 + 8 * 25, 508)
SKIN.Colours.Category.LineAlt.Button_Hover    = GWEN.TextureColor(4 + 8 * 24, 500)
SKIN.Colours.Category.LineAlt.Button_Selected = GWEN.TextureColor(4 + 8 * 25, 500)

SKIN.Colours.TooltipText                      = GWEN.TextureColor(4 + 8 * 26, 500)

--- Paints the background of a panel, if it has one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintPanel(panel, w, h)
  if !panel.m_bBackground then return end

  self.tex.Panels.Normal(0, 0, w, h, panel.m_bgColor)
end

--- Paints a drop shadow.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintShadow(panel, w, h)
  SKIN.tex.Shadow(0, 0, w, h)
end

--- Paints a window frame and its shadow, depending on whether the frame has focus.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintFrame(panel, w, h)
  if panel.m_bPaintShadow then
    local offset, grow = scale(4), scale(10)

    DisableClipping(true)
      SKIN.tex.Shadow(-offset, -offset, w + grow, h + grow)
    DisableClipping(false)
  end

  if panel:HasHierarchicalFocus() then
    self.tex.Window.Normal(0, 0, w, h)
  else
    self.tex.Window.Inactive(0, 0, w, h)
  end
end

--- Paints the background of a button according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButton(panel, w, h)
  if !panel.m_bBackground then return end

  if panel.Depressed or panel:IsSelected() or panel:GetToggle() then
    return self.tex.Button_Down(0, 0, w, h)
  end

  if panel:GetDisabled() then
    return self.tex.Button_Dead(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Button_Hovered(0, 0, w, h)
  end

  self.tex.Button(0, 0, w, h)
end

--- Paints the background of a tree view, if it has one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTree(panel, w, h)
  if !panel.m_bBackground then return end

  self.tex.Tree(0, 0, w, h, panel.m_bgColor)
end

--- Paints a checkbox according to whether it is checked and whether it is disabled.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintCheckBox(panel, w, h)
  if panel:GetChecked() then
    if panel:GetDisabled() then
      self.tex.CheckboxD_Checked(0, 0, w, h)
    else
      self.tex.Checkbox_Checked(0, 0, w, h)
    end
  else
    if panel:GetDisabled() then
      self.tex.CheckboxD(0, 0, w, h)
    else
      self.tex.Checkbox(0, 0, w, h)
    end
  end
end

--- Paints the plus or minus button that expands a tree node.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintExpandButton(panel, w, h)
  if !panel:GetExpanded() then
    self.tex.TreePlus(0, 0, w, h)
  else
    self.tex.TreeMinus(0, 0, w, h)
  end
end

--- Paints the background of a text entry according to its state, then draws its text.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTextEntry(panel, w, h)
  if panel.m_bBackground then
    if panel:GetDisabled() then
      self.tex.TextBox_Disabled(0, 0, w, h)
    elseif panel:HasFocus() then
      self.tex.TextBox_Focus(0, 0, w, h)
    else
      self.tex.TextBox(0, 0, w, h)
    end
  end

  panel:DrawTextEntryText(panel:GetTextColor(), panel:GetHighlightColor(), panel:GetCursorColor())
end

--- Paints the background of a menu, with or without the icon column.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenu(panel, w, h)
  if panel:GetDrawColumn() then
    self.tex.MenuBG_Column(0, 0, w, h)
  else
    self.tex.MenuBG(0, 0, w, h)
  end
end

--- Paints the separator line of a menu.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenuSpacer(panel, w, h)
  set_draw_color(shade_color)
  draw_rect(0, 0, w, h)
end

--- Paints the highlight of a hovered menu option and the check mark of a checked one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenuOption(panel, w, h)
  if panel.m_bBackground and (panel.Hovered or panel.Highlight) then
    self.tex.MenuBG_Hover(0, 0, w, h)
  end

  if panel:GetChecked() then
    local check_size = scale(15)

    self.tex.Menu_Check(scale(5), h * 0.5 - scale(7), check_size, check_size)
  end
end

--- Paints the arrow of a menu option that opens a submenu.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenuRightArrow(panel, w, h)
  self.tex.Menu.RightArrow(0, 0, w, h)
end

--- Paints the body of a property sheet below its tabs.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintPropertySheet(panel, w, h)
  local active_tab = panel:GetActiveTab()
  local offset = 0

  if active_tab then offset = active_tab:GetTall() - scale(8) end

  self.tex.Tab_Control(0, offset, w, h - offset)
end

--- Paints a tab of a property sheet, depending on whether it is the active one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTab(panel, w, h)
  if panel:GetPropertySheet():GetActiveTab() == panel then
    return self:PaintActiveTab(panel, w, h)
  end

  self.tex.TabT_Inactive(0, 0, w, h)
end

--- Paints the active tab of a property sheet.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintActiveTab(panel, w, h)
  self.tex.TabT_Active(0, 0, w, h)
end

--- Paints the close button of a window according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintWindowCloseButton(panel, w, h)
  if !panel.m_bBackground then return end

  if panel:GetDisabled() then
    return self.tex.Window.Close(0, 0, w, h, disabled_tint)
  end

  if panel.Depressed or panel:IsSelected() then
    return self.tex.Window.Close_Down(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Window.Close_Hover(0, 0, w, h)
  end

  self.tex.Window.Close(0, 0, w, h)
end

--- Paints the minimize button of a window according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintWindowMinimizeButton(panel, w, h)
  if !panel.m_bBackground then return end

  if panel:GetDisabled() then
    return self.tex.Window.Mini(0, 0, w, h, disabled_tint)
  end

  if panel.Depressed or panel:IsSelected() then
    return self.tex.Window.Mini_Down(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Window.Mini_Hover(0, 0, w, h)
  end

  self.tex.Window.Mini(0, 0, w, h)
end

--- Paints the maximize button of a window according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintWindowMaximizeButton(panel, w, h)
  if !panel.m_bBackground then return end

  if panel:GetDisabled() then
    return self.tex.Window.Maxi(0, 0, w, h, disabled_tint)
  end

  if panel.Depressed or panel:IsSelected() then
    return self.tex.Window.Maxi_Down(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Window.Maxi_Hover(0, 0, w, h)
  end

  self.tex.Window.Maxi(0, 0, w, h)
end

--- Paints the track of a vertical scroll bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintVScrollBar(panel, w, h)
  self.tex.Scroller.TrackV(0, 0, w, h)
end

--- Paints the grip of a scroll bar according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintScrollBarGrip(panel, w, h)
  if panel:GetDisabled() then
    return self.tex.Scroller.ButtonV_Disabled(0, 0, w, h)
  end

  if panel.Depressed then
    return self.tex.Scroller.ButtonV_Down(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Scroller.ButtonV_Hover(0, 0, w, h)
  end

  return self.tex.Scroller.ButtonV_Normal(0, 0, w, h)
end

--- Paints the 'down' button of a scroll bar according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButtonDown(panel, w, h)
  if !panel.m_bBackground then return end

  if panel.Depressed or panel:IsSelected() then
    return self.tex.Scroller.DownButton_Down(0, 0, w, h)
  end

  if panel:GetDisabled() then
    return self.tex.Scroller.DownButton_Dead(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Scroller.DownButton_Hover(0, 0, w, h)
  end

  self.tex.Scroller.DownButton_Normal(0, 0, w, h)
end

--- Paints the 'up' button of a scroll bar according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButtonUp(panel, w, h)
  if !panel.m_bBackground then return end

  if panel.Depressed or panel:IsSelected() then
    return self.tex.Scroller.UpButton_Down(0, 0, w, h)
  end

  if panel:GetDisabled() then
    return self.tex.Scroller.UpButton_Dead(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Scroller.UpButton_Hover(0, 0, w, h)
  end

  self.tex.Scroller.UpButton_Normal(0, 0, w, h)
end

--- Paints the 'left' button of a scroll bar according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButtonLeft(panel, w, h)
  if !panel.m_bBackground then return end

  if panel.Depressed or panel:IsSelected() then
    return self.tex.Scroller.LeftButton_Down(0, 0, w, h)
  end

  if panel:GetDisabled() then
    return self.tex.Scroller.LeftButton_Dead(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Scroller.LeftButton_Hover(0, 0, w, h)
  end

  self.tex.Scroller.LeftButton_Normal(0, 0, w, h)
end

--- Paints the 'right' button of a scroll bar according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintButtonRight(panel, w, h)
  if !panel.m_bBackground then return end

  if panel.Depressed or panel:IsSelected() then
    return self.tex.Scroller.RightButton_Down(0, 0, w, h)
  end

  if panel:GetDisabled() then
    return self.tex.Scroller.RightButton_Dead(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Scroller.RightButton_Hover(0, 0, w, h)
  end

  self.tex.Scroller.RightButton_Normal(0, 0, w, h)
end

--- Paints the drop-down arrow of a combo box according to the state of the combo box.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintComboDownArrow(panel, w, h)
  local combo_box = panel.ComboBox

  if combo_box:GetDisabled() then
    return self.tex.Input.ComboBox.Button.Disabled(0, 0, w, h)
  end

  if combo_box.Depressed or combo_box:IsMenuOpen() then
    return self.tex.Input.ComboBox.Button.Down(0, 0, w, h)
  end

  if combo_box.Hovered then
    return self.tex.Input.ComboBox.Button.Hover(0, 0, w, h)
  end

  self.tex.Input.ComboBox.Button.Normal(0, 0, w, h)
end

--- Paints the background of a combo box according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintComboBox(panel, w, h)
  if panel:GetDisabled() then
    return self.tex.Input.ComboBox.Disabled(0, 0, w, h)
  end

  if panel.Depressed or panel:IsMenuOpen() then
    return self.tex.Input.ComboBox.Down(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Input.ComboBox.Hover(0, 0, w, h)
  end

  self.tex.Input.ComboBox.Normal(0, 0, w, h)
end

--- Paints the background of a list box.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintListBox(panel, w, h)
  self.tex.Input.ListBox.Background(0, 0, w, h)
end

--- Paints the 'up' arrow of a number entry according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintNumberUp(panel, w, h)
  if panel:GetDisabled() then
    return self.tex.Input.UpDown.Up.Disabled(0, 0, w, h)
  end

  if panel.Depressed then
    return self.tex.Input.UpDown.Up.Down(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Input.UpDown.Up.Hover(0, 0, w, h)
  end

  self.tex.Input.UpDown.Up.Normal(0, 0, w, h)
end

--- Paints the 'down' arrow of a number entry according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintNumberDown(panel, w, h)
  if panel:GetDisabled() then
    return self.tex.Input.UpDown.Down.Disabled(0, 0, w, h)
  end

  if panel.Depressed then
    return self.tex.Input.UpDown.Down.Down(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Input.UpDown.Down.Hover(0, 0, w, h)
  end

  self.tex.Input.UpDown.Down.Normal(0, 0, w, h)
end

--- Paints the lines that connect a tree node to its parent, if the tree draws lines.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTreeNode(panel, w, h)
  if !panel.m_bDrawLines then return end

  set_draw_color(self.Colours.Tree.Lines)

  local x, y = scale(9), scale(7)

  draw_rect(x, 0, 1, panel.m_bLastChild and y or h)
  draw_rect(x, y, x, 1)
end

--- Paints the selection highlight behind the label of a selected tree node.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTreeNodeButton(panel, w, h)
  if !panel.m_bSelected then return end

  -- Don't worry this isn't working out the size every render
  -- it just gets the cached value from inside the Label
  local w, _ = panel:GetTextSize()

  self.tex.Selection(scale(38), 0, w + scale(6), h)
end

--- Paints a selection highlight.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintSelection(panel, w, h)
  self.tex.Selection(0, 0, w, h)
end

--- Paints the knob of a slider according to its state.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintSliderKnob(panel, w, h)
  if panel:GetDisabled() then return self.tex.Input.Slider.H.Disabled(0, 0, w, h) end

  if panel.Depressed then
    return self.tex.Input.Slider.H.Down(0, 0, w, h)
  end

  if panel.Hovered then
    return self.tex.Input.Slider.H.Hover(0, 0, w, h)
  end

  self.tex.Input.Slider.H.Normal(0, 0, w, h)
end

--- Paints the track of a number slider and its notches.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintNumSlider(panel, w, h)
  local x, y = scale(8), h * 0.5 - 1

  set_draw_color(shade_color)
  draw_rect(x, y, w - scale(15), 1)

  local notches = panel.m_iNotches

  if !notches then return end

  local space = (w - scale(16)) / notches
  local notch_y, notch_h = y + scale(4), scale(5)

  for i = 0, notches do
    draw_rect(x + i * space, notch_y, 1, notch_h)
  end
end

--- Paints a progress bar filled according to its fraction.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintProgress(panel, w, h)
  self.tex.ProgressBar.Back(0, 0, w, h)
  self.tex.ProgressBar.Front(0, 0, w * panel:GetFraction(), h)
end

--- Paints a collapsible category, or only its header when it is collapsed.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintCollapsibleCategory(panel, w, h)
  if h < scale(21) then
    return self.tex.categoryList.Header(0, 0, w, h)
  end

  self.tex.categoryList.Inner(0, 0, w, scale(63))
end

--- Paints the background of a category list.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintCategoryList(panel, w, h)
  self.tex.categoryList.Outer(0, 0, w, h)
end

--- Paints the background of a category button according to its state and line parity.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintCategoryButton(panel, w, h)
  local colours = panel.AltLine and self.Colours.Category.LineAlt or self.Colours.Category.Line

  if panel.Depressed or panel.m_bSelected then
    set_draw_color(colours.Button_Selected)
  elseif panel.Hovered then
    set_draw_color(colours.Button_Hover)
  else
    set_draw_color(colours.Button)
  end

  draw_rect(0, 0, w, h)
end

--- Paints the background of a list view line that is selected, hovered or alternate.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintListViewLine(panel, w, h)
  if panel:IsSelected() then
    self.tex.Input.ListBox.EvenLineSelected(0, 0, w, h)
  elseif panel.Hovered then
    self.tex.Input.ListBox.Hovered(0, 0, w, h)
  elseif panel.m_bAlt then
    self.tex.Input.ListBox.EvenLine(0, 0, w, h)
  end
end

--- Paints the background of a list view, if it has one.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintListView(panel, w, h)
  if !panel.m_bBackground then return end

  self.tex.Input.ListBox.Background(0, 0, w, h)
end

--- Paints the background of a tooltip.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintTooltip(panel, w, h)
  self.tex.Tooltip(0, 0, w, h)
end

--- Paints the background of a menu bar.
-- @param panel [Panel the panel being painted]
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function SKIN:PaintMenuBar(panel, w, h)
  self.tex.Menu_Strip(0, 0, w, h)
end

derma.DefineSkin('Flux', 'Made as a base for Flux skins.', SKIN)
