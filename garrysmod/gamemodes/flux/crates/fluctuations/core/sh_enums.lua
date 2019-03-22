-- DTVars
BOOL_INITIALIZED              = 0   -- Whether player has passed all initialization steps.

-- Bars
BAR_TOP                       = 0   -- Bars that are drawn on top of the screen (E.G. Health bar).
BAR_MANUAL                    = 1   -- Bars that are painted manually (E.G. progress bars).
BAR_HIDDEN                    = 2   -- Bars that are not currently being drawn.

-- File actions
FILE_ACTION_UNKNOWN           = 0   -- We don't know what happened to the file, but it apparently did.
FILE_ACTION_ADDED             = 1   -- The file was created.
FILE_ACTION_REMOVED           = 2   -- The file was removed.
FILE_ACTION_MODIFIED          = 3   -- The file was modified.
FILE_ACTION_RENAMED_OLD_NAME  = 4   -- The file was renamed, this is it's old name.
FILE_ACTION_RENAMED_NEW_NAME  = 5   -- The file was renamed, this is it's new name.

-- Config enums
CONFIG_PLUGIN                 = 0
CONFIG_SCHEMA                 = 1
CONFIG_FLUX                   = 2
