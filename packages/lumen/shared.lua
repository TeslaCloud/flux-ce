--- Entry point of the Lumen package, run on both realms.
-- Loads the library in dependency order: the registry of templates and the compiler on both
-- realms, then the clientside runtime (styles, layout, elements, state, the reconciler and the
-- intrinsic elements) and the panels that the intrinsic elements create. During a partial code
-- reload (`LITE_REFRESH`) nothing is loaded again.

if !LITE_REFRESH then
  require_relative 'lib/sh_lumen'
  require_relative 'lib/sh_compiler'
  require_relative 'lib/cl_style'
  require_relative 'lib/cl_layout'
  require_relative 'lib/cl_element'
  require_relative 'lib/cl_state'
  require_relative 'lib/cl_reconciler'
  require_relative 'lib/cl_elements'

  require_relative_folder('views', true)
end
