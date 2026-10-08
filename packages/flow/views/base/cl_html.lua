--- An HTML view (`fl_html`) that assembles its page from separate parts.
-- Set the parts with `set_head`, `set_css`, `set_body` and `set_javascript`, then call
-- `render` to build the document and display it; `set_html` displays a complete document as it
-- is. The help panel renders its templates into it. Derives from `DHTML`.

local PANEL = {}
PANEL.css = ''
PANEL.html_head = ''
PANEL.html_body = ''
PANEL.js = ''
PANEL.html_content = ''

--- Sets the markup placed inside the head element by the next call to render.
-- @param contents [String HTML]
function PANEL:set_head(contents)
  self.html_head = contents
end

--- Sets the markup placed inside the body element by the next call to render.
-- @param contents [String HTML]
function PANEL:set_body(contents)
  self.html_body = contents
end

--- Sets the script placed in a script tag at the end of the body by the next call to render.
-- @param contents [String JavaScript code]
function PANEL:set_javascript(contents)
  self.js = contents
end

--- Sets the stylesheet placed in a style tag in the head by the next call to render.
-- @param contents [String CSS]
function PANEL:set_css(contents)
  self.css = contents
end

--- Replaces the whole document with the given HTML and displays it right away.
-- @param contents [String a complete HTML document]
function PANEL:set_html(contents)
  self.html_content = contents
  self:SetHTML(self.html_content)
end

--- Builds a complete HTML document from the head, CSS, body and JavaScript parts and
-- displays it.
-- ```
-- self.html = vgui.Create('fl_html', self)
-- self.html:set_css(render_stylesheet('help'))
-- self.html:set_body(render_template('help'))
-- self.html:set_javascript(render_javascript('help'))
-- self.html:render()
-- ```
function PANEL:render()
  local html = '<!DOCTYPE html><html lang="en"><head>'
  html = html..(self.html_head or '')
  html = html..'<style>'..(self.css or '')..'</style></head>'
  html = html..'<body>'..(self.html_body or '')
  html = html..'<script type="text/javascript">'..(self.js or '')..'</script></body></html>'
  self:set_html(html)
end

vgui.Register('fl_html', PANEL, 'DHTML')
