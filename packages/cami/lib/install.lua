--- Installer of the CAMI package, run on both realms. CAMI, the Common Admin Mod Interface, is
-- the `CAMI` global through which admin mods register their usergroups and privileges and tell
-- each other when the usergroup of a player changes, and through which addons ask whether a
-- player has a privilege (`CAMI.PlayerHasAccess`) without knowing which admin mod the server
-- runs.
--
-- `lib/cami.lua` is the upstream library file, kept byte for byte. Many addons ship a copy of
-- it in their `autorun` folder, and the version check at its top lets the newest copy that the
-- server and the clients run win: an older copy returns without touching the global that a
-- newer one has set up, whichever of them is loaded first. The library creates the global
-- itself, which is why the package declares none.
-- @module [CAMI]

--- Called by the Package manager once the package has been included.
-- Sends the library to clients and runs it, which sets up the CAMI global unless a newer copy
-- has done so already.
function PACKAGE:__installed__()
  AddCSLuaFile(self.__path__..'lib/cami.lua')
  include(self.__path__..'lib/cami.lua')
end
