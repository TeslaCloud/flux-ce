--- Entry point of the Active UI package, run on both realms.
-- Loads the libraries, the classes and the metatable extensions, the base panels and the
-- views, registers the theme pipeline with the factory theme, and finally the hooks. On the
-- server it also registers the package's Lumen templates with `Pipeline`. During a partial
-- code reload (`LITE_REFRESH`) only the hooks are loaded again.

if !LITE_REFRESH then
  local package_path = PACKAGE.__path__

  require_relative_folder('lib', true)
  require_relative_folder('lib/classes', true)
  require_relative_folder('lib/meta', true)

  if SERVER then
    Pipeline.include_folder('lumen', package_path..'views/lumen')
  end

  require_relative_folder('views/base', true)
  require_relative_folder('views', true)

  if Theme or SERVER then
    --- Loads a theme file. On the client the file receives a fresh `ThemeBase` as `THEME` and
    -- the theme is registered once the file has run; on the server the file is only sent to
    -- the clients. The themes of the schema and of the plugins go through the same pipeline
    -- once they are included, after this package.
    Pipeline.register('theme', function(id, file_name, pipe)
      if CLIENT then
        THEME = ThemeBase.new(id)

        require_relative(file_name)

        THEME:register() THEME = nil
      else
        require_relative(file_name)
      end
    end)

    Pipeline.include_folder('theme', package_path..'themes')
  end
end

require_relative_folder('hooks', true)
