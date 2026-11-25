--- The help page of the tab menu (`fl_help`): the 'help' Lumen template mounted into the
-- panel. The template gives every page that has been added with `Flux.Help:add_page` a tab of
-- its own, so that is the place to add to the contents of this panel. `rebuild` renders the
-- template, which the tab menu calls once it has sized the panel. Derives from `fl_base_panel`.

local PANEL = {}

--- Mounts the help template, or renders it again with the pages that `Flux.Help:get_pages`
-- returns at that moment once it is mounted.
function PANEL:rebuild()
  if self.root then
    self.root:update()
  else
    self.root = Lumen.render('help', nil, self)
  end
end

--- Returns the size the tab menu gives this panel when it opens it.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(1280), math.scale(900)
end

vgui.Register('fl_help', PANEL, 'fl_base_panel')
