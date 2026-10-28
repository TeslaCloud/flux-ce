--- Selects the environment Flux runs in by returning its name.
-- The name is stored in the `FLUX_ENV` environment variable when the gamemode boots. A
-- `config/environment.local.lua` file is used instead of this one when it exists.
--
-- "production" is suited for normal server operation, since it runs faster at the expense
-- of errors being harder to debug and having more destructive effects.
-- "development" is suited for writing code for Flux, plugins or schemas. It uses safe mode
-- on hooks and prints more information to the console.
-- "test" runs like "development" and sets `IS_TEST`.

return 'production'
