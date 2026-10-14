--- Enumerations of the Stats plugin: the status code it adds to the character creation codes
-- of the Characters plugin, CHAR_ERR_ATTRIBUTE_SUM (the attribute levels of the new character
-- are missing, out of range or do not add up to the points a character gets).
-- lib/sh_attributes.lua includes this file, so the enumerations exist before the attributes
-- folder of the plugin is loaded.

enumerate('CHAR_ERR_ATTRIBUTE_SUM', 'CHAR')
