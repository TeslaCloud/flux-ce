--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

-- DTVars
BOOL_INITIALIZED	= 0		-- Whether player has passed all initialization steps.
BOOL_WEAPON_RAISED	= 1		-- Whether player has their active weapon raised.

ENT_RAGDOLL			= 2		-- Player's ragdoll (E.G. fallenover, death or anything else).

-- Permissions
PERM_NO				= 0		-- Not Set (no), means that this user has no permission.
PERM_ALLOW			= 1		-- Allow, means that user has this permission.
PERM_NEVER			= 2		-- Never, means that user will never have access to this permission, regardless of anything else.
PERM_ALLOW_OVERRIDE	= 3		-- System's Allow, forces this permission to be "Allow". Overrides "Never".
PERM_ERROR			= 999		-- In case something goes wrong.

-- Bars
BAR_TOP				= 0		-- Bars that are drawn on top of the screen (E.G. Health bar).
BAR_MANUAL			= 1		-- Bars that are painted manually (E.G. progress bars).
BAR_HIDDEN			= 2		-- Bars that are not currently being drawn.

-- Items system
ITEM_TEMPLATE		= -1	-- Item is a template and needs to be instantiated before use.
ITEM_INVALID		= 0		-- Item is either invalid or is a template and therefore cannot be instantiated.

-- File actions
FILE_ACTION_UNKNOWN				= 0	-- We don't know what happened to the file, but it apparently did.
FILE_ACTION_ADDED				= 1	-- The file was created.
FILE_ACTION_REMOVED				= 2	-- The file was removed.
FILE_ACTION_MODIFIED			= 3	-- The file was modified.
FILE_ACTION_RENAMED_OLD_NAME	= 4	-- The file was renamed, this is it's old name.
FILE_ACTION_RENAMED_NEW_NAME	= 5	-- The file was renamed, this is it's new name.

-- Config enums
CONFIG_PLUGIN		= 0
CONFIG_SCHEMA		= 1
CONFIG_FLUX			= 2