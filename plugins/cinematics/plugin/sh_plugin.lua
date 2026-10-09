--- Cinematics shows cinematics: black letterbox bars slide in from the top and the bottom of
-- the screen, text fades in, stays for a while and fades out, and the bars slide back out.
-- A cinematic has a caption on the bottom bar, a title with a subtitle in the middle of the
-- screen, or both. Cinematics are queued on the client and played one after another; the bars
-- stay in place between two of them. While the bars are on screen the top bars, the info
-- display and the crosshair are hidden, and the bars are drawn above the rest of the HUD.
--
-- The server shows a cinematic to one player, a list of players or everyone with
-- `Cinematics:show` and takes them off the screen with `Cinematics:clear`. Client code queues
-- one for the local player with `Cinematics:add`.
-- ```
-- -- Server: a caption for everyone.
-- Cinematics:show(nil, 'The curfew has begun.')
--
-- -- Server: a title card for one player, with a language phrase as the caption.
-- Cinematics:show(target, {
--   title = 'Chapter One',
--   subtitle = 'Point Insertion',
--   text = 'my_schema.chapter_one.caption',
--   arguments = { name = target:name() },
--   duration = 8
-- })
-- ```
--
-- When a player loads a character for the first time since joining, the plugin plays an intro:
-- the name of the schema as the title, its description as the subtitle and a credits line
-- with its author as the caption. The 'cinematic_intro' config turns the intro off, and the
-- `GetCinematicIntroInfo` hook lets a schema change, replace or suppress it.
--
-- The look comes from the theme, which the plugin fills in from its `OnThemeLoaded` handler:
-- the 'cinematic_bar_size', 'cinematic_duration', 'cinematic_slide_time' and
-- 'cinematic_fade_time' options, the 'cinematic_bars', 'cinematic_text' and 'cinematic_title'
-- colors and the 'cinematic_caption', 'cinematic_title' and 'cinematic_subtitle' fonts. The
-- handler of a schema runs after the one of the plugin, so a schema overrides them from its
-- own `OnThemeLoaded`.
-- @module [Cinematics]

PLUGIN:set_global('Cinematics')

require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
