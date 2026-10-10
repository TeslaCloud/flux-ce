# Lua Lumen for Visual Studio Code

Syntax highlighting for `.lumen` files: the templates of the Lumen package of Flux, which are
Garry's Mod Lua with markup in them.

```lua
local Card = Lumen.require('card')

return function(props)
  local count, set_count = use_state(0)

  return <view style={{ gap = 4 }}>
    <Card title={props.title} />
    <text>Clicked {count} times</text>
    <button on_press={function() set_count(count + 1) end}>Click</button>
  </view>
end
```

## What it highlights

- GLua: keywords, `local`, `function`, strings (quoted and long), numbers, comments (`--`,
  `--[[ ]]`, `//`, `/* */`), the `!`, `!=`, `&&` and `||` operators, `continue`, function
  definitions and calls, `self` and the realm globals.
- Markup: tags, with intrinsic elements (`view`, `text`, `button`, ...) told apart from
  components (`Card`, `Flux.Panels.Card`), fragments (`<>...</>`), attribute names, quoted
  attribute values, `{expression}` attributes and children with Lua highlighted inside,
  `{...spread}` attributes, `<!-- comments -->` and character entities.
- The Lumen API: `use_state` and the other hooks, `Lumen.element`, `Lumen.map` and friends.

A `<` only starts markup where an operand may start (after `return`, `and`, `or`, `(`, `{`,
`,`, `=` or at the start of a line) and when a tag name follows it at once, so comparisons
such as `a < b` keep their operator color. The language configuration adds `--` comments,
bracket matching for tags, auto-closing pairs and indentation for Lua blocks and tags.

## Installing

From a checkout of Flux, either link the folder into your extensions:

```sh
ln -s "$(pwd)/packages/lumen/ext" ~/.vscode/extensions/flux.lua-lumen
```

or package and install it:

```sh
cd packages/lumen/ext
npx @vscode/vsce package
code --install-extension lua-lumen-1.0.0.vsix
```

Restart or reload the window afterwards. Files ending in `.lumen` then open as Lua Lumen.
