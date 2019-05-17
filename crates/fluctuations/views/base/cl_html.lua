
local PANEL = {}
PANEL.css = ''
PANEL.html_head = ''
PANEL.html_body = ''
PANEL.js = ''
PANEL.html_content = ''

function PANEL:set_head(contents)
  self.html_head = contents
end

function PANEL:set_body(contents)
  self.html_body = contents
end

function PANEL:set_javascript(contents)
  self.js = contents
end

function PANEL:set_css(contents)
  self.css = contents
end

function PANEL:set_html(contents)
  self.html_content = contents
  self:SetHTML(self.html_content)
end

function PANEL:render()
  local html = '<!DOCTYPE html><html lang="en"><head>'
  html = html..self.html_head
  html = html..'<style>'..(self.css or '')..'</style></head>'
  html = html..'<body>'..(self.html_body or '')
  html = html..'<script type="text/javascript">'..self.js..'</script></body></html>'
  self:set_html(html)
end

vgui.Register('fl_html', PANEL, 'DHTML')
