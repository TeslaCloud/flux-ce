--- Client side of the registry of templates: stores the templates of the generated client
-- files, which fill `Flux.lumen_sources` before Lumen loads. A template whose ID is also the
-- name of an element is reported, since the element is what a tag of that name creates.
-- @module [Lumen]

if istable(Flux) and istable(Flux.lumen_sources) then
  for id, source in pairs(Flux.lumen_sources) do
    if Lumen.find_element(id) then
      ErrorNoHalt("Lumen: the '"..id.."' template of '"..tostring(source.path).."' has the name of an element, "..
        'which takes its place in markup!\n')
    end

    Lumen.define(id, source.path, source.code, source.error)
  end
end
