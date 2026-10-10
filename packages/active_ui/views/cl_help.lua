--- The help page of the tab menu (`fl_help`): the 'help' Lumen template mounted into the
-- panel. The template gives every page that has been added with `Flux.Help:add_page` a tab of
-- its own, so that is the place to add to the contents of this panel. `rebuild` renders the
-- template again. Derives from `fl_base_panel`.

local PANEL = {}

--- Mounts the help template.
function PANEL:Init()
  self.root = Lumen.render('help', nil, self)
end

--- Renders the help template again, with the pages that `Flux.Help:get_pages` returns at that
-- moment.
function PANEL:rebuild()
  if self.root then
    self.root:update()
  else
    self.root = Lumen.render('help', nil, self)
  end
end

--- Takes the template down with the panel.
function PANEL:OnRemove()
  if self.root then
    self.root:unmount()
    self.root = nil
  end
end

--- Returns the size the tab menu gives this panel when it opens it.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(1280), math.scale(900)
end

vgui.Register('fl_help', PANEL, 'fl_base_panel')
