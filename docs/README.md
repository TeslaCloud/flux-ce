# Flux Documentation

* [Writing plugins and schemas](plugins.md): the folder layout of a plugin, its hooks, commands, roles, configs, phrases, items, species, factions, migrations and net messages, with an example of each. Read it before you write a plugin or a schema.
* The API reference: every library, class, hook and definition of Flux, generated from the doc comments in the code by [fdoc](https://github.com/Meow/fdoc). The reference of the latest release is at https://docs.fluxpkg.dev/flux/; `fpkg docs flux` opens it as well, and `fpkg docs flux@0.9.0` the one of a given version.
* [`fdoc_demo.lua`](fdoc_demo.lua) shows every tag that fdoc understands in a doc comment. The [fdoc README](https://github.com/Meow/fdoc) describes the format.

## Building the reference

Install fdoc as its README says, then run it in the root of your checkout of Flux with an output folder outside of the checkout:

```sh
fdoc . -o ../flux-reference
```

and open `../flux-reference/index.html`. Always pass `-o`: the default output folder of fdoc is the `docs` folder of the source, which is this folder. fdoc leaves `docs` folders out of what it reads, so neither this folder nor the demo is part of the reference.
