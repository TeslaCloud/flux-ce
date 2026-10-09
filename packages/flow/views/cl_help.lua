--- The help page of the tab menu (`fl_help`): an `fl_html` view that shows the 'help' template
-- rendered with its stylesheet and JavaScript. The template gives every page that has been
-- added with `Flux.Help:add_page` a tab of its own, so that is the place to add to the
-- contents of this panel.
-- `rebuild` renders the page again. Derives from `fl_base_panel`.

local PANEL = {}
PANEL.categories = {}

--- Creates the HTML view and renders the help page into it.
function PANEL:Init()
  self.html = vgui.Create('fl_html', self)
  self.html:Dock(FILL)
  self:rebuild()
end

--- Renders the help page again from the 'help' stylesheet, template and JavaScript, with
-- the pages that `Flux.Help:get_pages` returns at that moment.
function PANEL:rebuild()
  self.html:set_css(render_stylesheet('help'))
  self.html:set_body(render_template('help'))
  self.html:set_javascript(render_javascript('help'))
  self.html:render()
end

--- Returns the size the tab menu gives this panel when it opens it.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(1280), math.scale(900)
end

vgui.Register('fl_help', PANEL, 'fl_base_panel')
