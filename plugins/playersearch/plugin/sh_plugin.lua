--- Player Search lets a player search the inventory of another player who is facing away
-- from them. The search is asked for from the interaction menu of that player, who allows it
-- or resists. An allowed search opens their inventory to the searcher until the searcher
-- closes it or the search is no longer allowed, for example because the searched player turned
-- around or the two moved apart. `CanStartSearch` decides whether a search may be asked for,
-- `CanSearch` whether it may start and go on.

PLUGIN:set_global 'PlayerSearch'

require_relative 'cl_hooks'
require_relative 'cl_nethooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
require_relative 'sv_nethooks'
