-- DTVars
BOOL_INITIALIZED = 0;
BOOL_WEAPON_RAISED = 1;

-- Permissions
PERM_NO = 0;				-- Not Set (no), means that this user has no permission.
PERM_ALLOW = 1;				-- Allow, means that user has this permission.
PERM_NEVER = 2;				-- Never, means that user will never have access to this permission, regardless of anything else.
PERM_ALLOW_OVERRIDE = 3;	-- System's Allow, forces this permission to be "Allow". Overrides "Never".
PERM_ERROR = 999;			-- In case something goes wrong.

-- Character System Codes
CHAR_SUCCESS = 0;		 -- Character successfully created.
CHAR_ERR_NAME = 1;		 -- Character's name is invalid.
CHAR_ERR_DESC = 2;		 -- Character's description is invalid.
CHAR_ERR_GENDER = 3;	 -- Character's gender is invalid.
CHAR_ERR_FACTION = 4;	 -- Character's faction is invalid.
CHAR_ERR_CLASS = 5;		 -- Character's class is invalid.
CHAR_ERR_EXISTS = 6;	 -- Character already exists.
CHAR_ERR_LIMIT = 7;		 -- Player has hit characters limit.
CHAR_GENDER_MALE = 8;	 -- Guys
CHAR_GENDER_FEMALE = 9;	 -- Gals
CHAR_GENDER_NONE = 10;	 -- Gender-less characters such as vorts.
CHAR_ERR_UNKNOWN = 999;	 -- Something else went wrong.

-- Bars
BAR_TOP = 0;
BAR_MANUAL = 1;
BAR_HIDDEN = 2;