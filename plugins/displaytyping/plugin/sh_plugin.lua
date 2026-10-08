--- Display Typing shows players what the characters around them are typing.
-- The text a player types into the chatbox is networked as they type, and players within 350
-- units who have a clear line of sight see it above the head of the typing player, fading with
-- distance. When the 'display_exact_message' config is disabled a label such as 'typing' is
-- shown instead of the text; plugins choose the label through the `DisplayTypingTextType` hook
-- and scale the visibility and fade distances through `DisplayTypingAdjustFadeoffMultiplier`.
-- @module [DisplayTyping]

PLUGIN:set_global('DisplayTyping')

require_relative 'cl_plugin'
require_relative 'sv_plugin'
require_relative 'cl_hooks'
