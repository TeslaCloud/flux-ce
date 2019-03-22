-- Include the required third-party libraries.
if !string.utf8upper or !pon or !Cable then
  include 'lib/vendor/utf8.min.lua'
  include 'lib/vendor/pon.min.lua'
  Cable     = include 'lib/vendor/cable.min.lua'
  Markdown  = include 'lib/vendor/markdown.min.lua'
end
