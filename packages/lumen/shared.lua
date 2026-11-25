--- Entry point of the Lumen package, run on both realms.
-- Loads the library in dependency order: the registry of templates and the compiler on both
-- realms, the server side of the registry (the `lumen` pipeline and the generated client
-- files), then the clientside runtime (styles, layout, elements, state, the reconciler and the
-- intrinsic elements), the client side of the registry, the panels that the intrinsic elements
-- create and the hooks. During a partial code reload (`LITE_REFRESH`) nothing is loaded again.

if !LITE_REFRESH then
  require_relative 'lib/sh_lumen'
  require_relative 'lib/sh_compiler'
  require_relative 'lib/sv_lumen'
  require_relative 'lib/cl_style'
  require_relative 'lib/cl_layout'
  require_relative 'lib/cl_element'
  require_relative 'lib/cl_state'
  require_relative 'lib/cl_reconciler'
  require_relative 'lib/cl_elements'
  require_relative 'lib/cl_lumen'

  require_relative_folder('views', true)
  require_relative_folder('hooks', true)
end
