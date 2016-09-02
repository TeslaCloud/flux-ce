-- DTVars
BOOL_INITIALIZED = 0;

-- Permissions
PERM_NO = 0;				-- Not Set (no), means that this user has no permission.
PERM_ALLOW = 1;				-- Allow, means that user has this permission.
PERM_NEVER = 2;				-- Never, means that user will never have access to this permission, regardless of anything else.
PERM_ALLOW_OVERRIDE = 3;	-- System's Allow, forces this permission to be "Allow". Overrides "Never".
PERM_ERROR = 999;			-- In case something goes wrong.