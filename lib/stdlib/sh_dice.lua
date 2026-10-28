--- Dice formulas: the `Dice` module parses formulas such as `2d6kh1 + strength` into a syntax
-- tree, rolls them and formats the outcome for display.
-- Formulas are case-insensitive and whitespace between tokens is ignored. They are made of:
-- * numbers (`3`, `2.5`), parentheses, binary `+ - * / %`, unary `-` and `^` (power);
-- * dice terms `NdS` (`d20` is `1d20`), fudge dice `dF`/`NdF` (-1 to 1) and `d%` (`d100`);
--   the count and the sides may also be a parenthesized expression or a `{variable}`;
-- * modifiers right after a dice term, any number of them in any order: `kh N`/`k N` keep the
--   highest, `kl N` keep the lowest, `dh N` drop the highest, `dl N` drop the lowest (N is 1
--   when left out), `!` explode on the highest face, `!N` explode on N or more (at most 100
--   extra dice per term), `r N`/`ro N` reroll once when N or less, `rr N` reroll until above N
--   (at most 100 times per die), `min N`/`max N` clamp every die;
-- * functions `floor(x)`, `ceil(x)`, `round(x)`, `abs(x)`, `min(a, b, ...)`, `max(a, b, ...)`;
-- * variables: bare names such as `strength` or names in braces such as `{level}`, looked up
--   in lower case.
-- A term rolls at most 1000 dice, a formula at most 10000, and dice have 1 to 10000 sides.
-- Rerolls and explosions happen while rolling, clamps apply to every die, then keep and drop
-- modifiers apply in the order they are written. Division results are not rounded.
-- ```
-- Dice.roll('1d20 + 5')                       -- 1d20 (14) + 5 = 19
-- Dice.roll('4d6kh3')                         -- 4d6kh3 (5, 4, 3, [1]) = 12
-- Dice.roll('2d20kl1 + {stealth}', { stealth = 3 })
-- Dice.roll('d6! + floor(level / 2)', function(name) return 4 end)
-- Dice.roll('3dF + 4d10rr1 min 2')
-- ```

local ipairs = ipairs
local pcall = pcall
local error = error
local tostring = tostring
local tonumber = tonumber
local math_floor = math.floor
local math_ceil = math.ceil
local math_abs = math.abs
local math_min = math.min
local math_huge = math.huge
local math_random = math.random
local table_sort = table.sort
local table_concat = table.concat
local string_sub = string.sub
local string_find = string.find
local string_match = string.match
local string_gsub = string.gsub
local string_lower = string.lower
local string_format = string.format

mod 'Dice'

local max_term_dice = 1000
local max_formula_dice = 10000
local max_sides = 10000
local max_explosions = 100
local max_rerolls = 100
local max_nesting = 64

local binary_precedence = {
  ['+'] = 1,
  ['-'] = 1,
  ['*'] = 2,
  ['/'] = 2,
  ['%'] = 2
}

local single_characters = {
  ['+'] = true,
  ['-'] = true,
  ['*'] = true,
  ['/'] = true,
  ['%'] = true,
  ['^'] = true,
  [','] = true
}

local modifier_names = { 'min', 'max', 'kh', 'kl', 'dh', 'dl', 'ro', 'rr', 'k', 'r' }

local keep_modifiers = {
  k = 'kh',
  kh = 'kh',
  kl = 'kl',
  dh = 'dh',
  dl = 'dl'
}

local function_arity = {
  floor = 1,
  ceil = 1,
  round = 1,
  abs = 1,
  min = 0,
  max = 0
}

--- Stops parsing or evaluation with an error message that names a position in the formula.
-- The error is caught by the public functions and returned as a message.
-- @param message [String what went wrong]
-- @param position [Number character position in the formula, starting at 1]
local function fail(message, position)
  error({ message = message..' at position '..position }, 0)
end

local function is_digit(char)
  return char != '' and string_find('0123456789', char, 1, true) != nil
end

local function is_name_start(char)
  return char != '' and string_find('abcdefghijklmnopqrstuvwxyz_', char, 1, true) != nil
end

local function is_name_char(char)
  return is_name_start(char) or is_digit(char)
end

local function is_whole(value)
  return value == math_floor(value)
end

local function is_finite(value)
  return value == value and value != math_huge and value != -math_huge
end

--- Decides whether a `d` in the formula starts a dice term rather than a variable name.
-- After a number, a closing parenthesis or a braced variable it always does. Where an operand
-- is expected it does when the die sides follow (a digit, `%`, `(`, `{` or a lone `f`).
-- @param previous [Table the token before the `d`, or nil at the start of the formula]
-- @param text [String lower case formula]
-- @param index [Number position of the `d`]
-- @return [Boolean whether the `d` is a dice operator]
local function starts_dice(previous, text, index)
  if previous then
    local kind = previous.kind

    if kind == 'number' or kind == 'variable' or (kind == 'op' and previous.value == ')') then
      return true
    end

    if kind != 'op' then
      return false
    end
  end

  local next_char = string_sub(text, index + 1, index + 1)

  if is_digit(next_char) or next_char == '%' or next_char == '(' or next_char == '{' then
    return true
  end

  return next_char == 'f' and !is_name_char(string_sub(text, index + 2, index + 2))
end

local function match_modifier(text, index)
  for _, name in ipairs(modifier_names) do
    if string_sub(text, index, index + #name - 1) == name then
      return name
    end
  end
end

--- Splits a formula into tokens.
-- Tokens are tables with `kind` ('number', 'name', 'variable', 'op', 'dice', 'fudge', 'percent',
-- 'modifier', 'explode' or 'eof'), `value`, `text`, `pos` and `finish` (first and last
-- character positions).
-- @param source [String formula as given]
-- @return [Table list of tokens ending with an 'eof' token]
local function tokenize(source)
  local text = string_lower(source)
  local length = #text
  local tokens = {}
  local index = 1
  local depth = 0
  local after_dice = false
  local sides_pending = false
  local sides_parens = {}

  local function push(kind, value, start, finish)
    local token = {
      kind = kind,
      value = value,
      text = string_sub(source, start, finish),
      pos = start,
      finish = finish
    }

    tokens[#tokens + 1] = token

    return token
  end

  while index <= length do
    local char = string_sub(text, index, index)

    if string_find(char, '%s') then
      index = index + 1
    else
      local expecting_sides = sides_pending

      sides_pending = false

      if expecting_sides and char == 'f' then
        push('fudge', 'f', index, index)
        after_dice = true
        index = index + 1
      elseif expecting_sides and char == '%' then
        push('percent', 100, index, index)
        after_dice = true
        index = index + 1
      elseif is_digit(char) or (char == '.' and is_digit(string_sub(text, index + 1, index + 1))) then
        local number_text = string_match(text, '^%d*%.%d+', index) or string_match(text, '^%d+', index)
        local finish = index + #number_text - 1

        push('number', tonumber(number_text), index, finish)

        if expecting_sides then
          after_dice = true
        end

        index = finish + 1
      elseif after_dice and char == '!' then
        push('explode', '!', index, index)
        index = index + 1
      elseif after_dice and is_name_start(char) then
        local name = match_modifier(text, index)

        if !name then
          local word = string_match(text, '^[%w_]+', index)

          fail("Unknown dice modifier '"..string_sub(source, index, index + #word - 1).."'", index)
        end

        push('modifier', name, index, index + #name - 1)
        index = index + #name
      elseif is_name_start(char) then
        if char == 'd' and starts_dice(tokens[#tokens], text, index) then
          push('dice', 'd', index, index)
          sides_pending = true
          after_dice = false
          index = index + 1
        else
          local name = string_match(text, '^[%w_]+', index)
          local finish = index + #name - 1

          push('name', name, index, finish)
          index = finish + 1
        end
      elseif char == '{' then
        local close = string_find(text, '}', index + 1, true)

        if !close then
          fail("Expected '}' to close '{'", index)
        end

        local name = string_match(string_sub(text, index + 1, close - 1), '^%s*(.-)%s*$')

        if name == '' then
          fail('Empty variable name', index)
        end

        push('variable', name, index, close)

        if expecting_sides then
          after_dice = true
        end

        index = close + 1
      elseif char == '(' then
        depth = depth + 1

        if expecting_sides then
          sides_parens[#sides_parens + 1] = depth
        end

        push('op', '(', index, index)
        after_dice = false
        index = index + 1
      elseif char == ')' then
        if sides_parens[#sides_parens] == depth then
          sides_parens[#sides_parens] = nil
          after_dice = true
        else
          after_dice = false
        end

        depth = depth - 1
        push('op', ')', index, index)
        index = index + 1
      elseif single_characters[char] then
        push('op', char, index, index)
        after_dice = false
        index = index + 1
      else
        fail("Unexpected character '"..string_sub(source, index, index).."'", index)
      end
    end
  end

  push('eof', nil, length + 1, length)

  return tokens
end

local function peek(state)
  return state.tokens[state.index]
end

local function advance(state)
  local token = state.tokens[state.index]

  if token.kind != 'eof' then
    state.index = state.index + 1
  end

  return token
end

local function is_op(token, value)
  return token.kind == 'op' and token.value == value
end

local function describe(token)
  if token.kind == 'eof' then
    return 'end of formula'
  end

  return "'"..token.text.."'"
end

local parse_expression

--- Parses the arguments of a function call up to and including the closing parenthesis.
-- @param state [Table parser state]
-- @param name_token [Table the token holding the function name]
-- @return [Table call node]
local function parse_call(state, name_token)
  local open = advance(state)
  local args = {}

  if !is_op(peek(state), ')') then
    args[1] = parse_expression(state, 1)

    while is_op(peek(state), ',') do
      advance(state)
      args[#args + 1] = parse_expression(state, 1)
    end
  end

  local close = peek(state)

  if !is_op(close, ')') then
    fail("Expected ')' to close '"..name_token.text.."(' from position "..open.pos..', found '..describe(close),
      close.pos)
  end

  advance(state)

  local arity = function_arity[name_token.value]

  if arity == 0 and #args == 0 then
    fail("Function '"..name_token.text.."' needs at least one argument", name_token.pos)
  elseif arity > 0 and #args != arity then
    fail("Function '"..name_token.text.."' takes exactly "..arity..' argument'..(arity == 1 and '' or 's'),
      name_token.pos)
  end

  return { kind = 'call', name = name_token.value, args = args, pos = name_token.pos, finish = close.finish }
end

--- Parses a number, a variable, a function call or a parenthesized expression.
-- @param state [Table parser state]
-- @return [Table syntax tree node]
local function parse_atom(state)
  local token = advance(state)
  local kind = token.kind

  if kind == 'number' then
    return { kind = 'number', value = token.value, pos = token.pos, finish = token.finish }
  elseif kind == 'variable' then
    return { kind = 'variable', name = token.value, pos = token.pos, finish = token.finish }
  elseif kind == 'name' then
    if is_op(peek(state), '(') then
      if !function_arity[token.value] then
        fail("Unknown function '"..token.text.."'", token.pos)
      end

      return parse_call(state, token)
    end

    return { kind = 'variable', name = token.value, pos = token.pos, finish = token.finish }
  elseif is_op(token, '(') then
    local expression = parse_expression(state, 1)
    local close = peek(state)

    if !is_op(close, ')') then
      fail("Expected ')' to close '(' from position "..token.pos..', found '..describe(close), close.pos)
    end

    advance(state)

    return { kind = 'group', expression = expression, pos = token.pos, finish = close.finish }
  end

  fail('Unexpected '..describe(token), token.pos)
end

local function parse_modifier_number(state, modifier, optional)
  local token = peek(state)

  if token.kind == 'number' then
    advance(state)

    return token.value
  end

  if !optional then
    fail("Expected a number after '"..modifier.text.."'", token.pos)
  end
end

--- Parses the sides and the modifiers of a dice term.
-- @param state [Table parser state]
-- @param count [Table node for the number of dice, or nil for one die]
-- @param start [Number position where the term starts]
-- @return [Table dice node]
local function parse_dice(state, count, start)
  local operator = advance(state)
  local token = advance(state)
  local node = { kind = 'dice', count = count, pos = start, keep = {}, rerolls = {} }

  if token.kind == 'fudge' then
    node.fudge = true
  elseif token.kind == 'percent' then
    node.sides = { kind = 'number', value = 100, pos = token.pos, finish = token.finish }
  elseif token.kind == 'number' then
    node.sides = { kind = 'number', value = token.value, pos = token.pos, finish = token.finish }
  elseif token.kind == 'variable' then
    node.sides = { kind = 'variable', name = token.value, pos = token.pos, finish = token.finish }
  elseif is_op(token, '(') then
    state.index = state.index - 1
    node.sides = parse_atom(state)
  else
    fail("Expected die sides after '"..operator.text.."', found "..describe(token), token.pos)
  end

  while true do
    local modifier = peek(state)

    if modifier.kind == 'explode' then
      advance(state)
      node.explode = parse_modifier_number(state, modifier, true) or true
    elseif modifier.kind == 'modifier' then
      advance(state)

      local name = modifier.value
      local keep_mode = keep_modifiers[name]

      if keep_mode then
        local amount = parse_modifier_number(state, modifier, true) or 1

        if amount < 0 or !is_whole(amount) then
          fail("The number after '"..modifier.text.."' must be a whole number", modifier.pos)
        end

        node.keep[#node.keep + 1] = { mode = keep_mode, amount = amount }
      elseif name == 'min' or name == 'max' then
        node[name] = parse_modifier_number(state, modifier, false)
      else
        node.rerolls[#node.rerolls + 1] = {
          threshold = parse_modifier_number(state, modifier, false),
          repeated = name == 'rr'
        }
      end
    else
      break
    end
  end

  node.finish = state.tokens[state.index - 1].finish

  if count and count.kind == 'number' then
    if !is_whole(count.value) or count.value > max_term_dice then
      fail('Dice count must be a whole number from 0 to '..max_term_dice, count.pos)
    end
  end

  if node.sides and node.sides.kind == 'number' then
    local sides = node.sides.value

    if !is_whole(sides) or sides < 1 or sides > max_sides then
      fail('Dice must have a whole number of sides from 1 to '..max_sides, node.sides.pos)
    end
  end

  state.dice = state.dice + ((count and count.kind == 'number') and count.value or 1)

  if state.dice > max_formula_dice then
    fail('Too many dice in formula (at most '..max_formula_dice..')', start)
  end

  return node
end

--- Parses an atom and the dice term it may be the count of.
-- @param state [Table parser state]
-- @return [Table syntax tree node]
local function parse_postfix(state)
  local token = peek(state)

  if token.kind == 'dice' then
    return parse_dice(state, nil, token.pos)
  end

  local atom = parse_atom(state)

  if peek(state).kind == 'dice' then
    return parse_dice(state, atom, atom.pos)
  end

  return atom
end

local parse_unary

--- Parses a power, which is right-associative and binds tighter than unary minus.
-- @param state [Table parser state]
-- @return [Table syntax tree node]
local function parse_power(state)
  local base = parse_postfix(state)
  local token = peek(state)

  if is_op(token, '^') then
    advance(state)

    local exponent = parse_unary(state)

    return {
      kind = 'binary',
      op = '^',
      left = base,
      right = exponent,
      pos = base.pos,
      op_pos = token.pos,
      finish = exponent.finish
    }
  end

  return base
end

--- Parses unary minus, so that `-2 ^ 2` is `-(2 ^ 2)`.
-- @param state [Table parser state]
-- @return [Table syntax tree node]
parse_unary = function(state)
  local token = peek(state)

  if is_op(token, '-') then
    state.depth = state.depth + 1

    if state.depth > max_nesting then
      fail('Formula is nested too deeply', token.pos)
    end

    advance(state)

    local operand = parse_unary(state)

    state.depth = state.depth - 1

    return { kind = 'negate', operand = operand, pos = token.pos, finish = operand.finish }
  end

  return parse_power(state)
end

--- Parses binary operators by precedence climbing.
-- @param state [Table parser state]
-- @param min_precedence [Number lowest operator precedence this call may consume]
-- @return [Table syntax tree node]
parse_expression = function(state, min_precedence)
  state.depth = state.depth + 1

  if state.depth > max_nesting then
    fail('Formula is nested too deeply', peek(state).pos)
  end

  local left = parse_unary(state)

  while true do
    local token = peek(state)
    local precedence = token.kind == 'op' and binary_precedence[token.value]

    if !precedence or precedence < min_precedence then
      break
    end

    advance(state)

    local right = parse_expression(state, precedence + 1)

    left = {
      kind = 'binary',
      op = token.value,
      left = left,
      right = right,
      pos = left.pos,
      op_pos = token.pos,
      finish = right.finish
    }
  end

  state.depth = state.depth - 1

  return left
end

local function parse_formula(source)
  local tokens = tokenize(source)
  local state = { tokens = tokens, index = 1, depth = 0, dice = 0 }

  if tokens[1].kind == 'eof' then
    fail('Empty formula', 1)
  end

  local expression = parse_expression(state, 1)
  local token = peek(state)

  if token.kind != 'eof' then
    fail('Unexpected '..describe(token), token.pos)
  end

  return { kind = 'formula', formula = source, expression = expression }
end

local function error_message(err)
  if istable(err) and err.message then
    return err.message
  end

  return 'Internal dice error: '..tostring(err)
end

--- Looks up the value of a variable.
-- @param variables [Table/Function map of names to numbers, or function(name) returning a number]
-- @param node [Table variable node]
-- @return [Number the value]
local function resolve_variable(variables, node)
  local name = node.name
  local value = nil

  if istable(variables) then
    value = variables[name]
  elseif isfunction(variables) then
    local success, result = pcall(variables, name)

    if !success then
      fail("Looking up variable '"..name.."' failed ("..tostring(result)..')', node.pos)
    end

    value = result
  end

  if isstring(value) then
    value = tonumber(value)

    if value == nil then
      fail("Variable '"..name.."' is not a number", node.pos)
    end
  end

  if value == nil then
    fail("Unknown variable '"..name.."'", node.pos)
  end

  if !isnumber(value) or !is_finite(value) then
    fail("Variable '"..name.."' is not a number", node.pos)
  end

  return value
end

--- Rounds a number to the nearest whole number, halves away from zero.
-- @param value [Number]
-- @return [Number rounded value]
local function round(value)
  if value < 0 then
    return -math_floor(-value + 0.5)
  end

  return math_floor(value + 0.5)
end

local evaluate_node

--- Rolls one die and applies the reroll modifiers of its term.
-- @param node [Table dice node]
-- @param low [Number lowest face]
-- @param high [Number highest face]
-- @return [Number the face that stays]
local function roll_die(node, low, high)
  local value = math_random(low, high)

  for _, reroll in ipairs(node.rerolls) do
    local threshold = reroll.threshold

    if reroll.repeated then
      local attempts = 0

      while value <= threshold and attempts < max_rerolls do
        value = math_random(low, high)
        attempts = attempts + 1
      end
    elseif value <= threshold then
      value = math_random(low, high)
    end
  end

  return value
end

local function clamp_die(node, value)
  if node.min and value < node.min then
    value = node.min
  end

  if node.max and value > node.max then
    value = node.max
  end

  return value
end

--- Applies the keep and drop modifiers of a term, in the order they are written.
-- @param node [Table dice node]
-- @param results [Table list of die values]
-- @return [Table map of result indices to true for every dropped die]
local function apply_keep(node, results)
  local dropped = {}

  for _, rule in ipairs(node.keep) do
    local remaining = {}

    for i = 1, #results do
      if !dropped[i] then
        remaining[#remaining + 1] = i
      end
    end

    table_sort(remaining, function(a, b)
      if results[a] == results[b] then
        return a < b
      end

      return results[a] < results[b]
    end)

    local total = #remaining
    local amount = math_min(rule.amount, total)
    local mode = rule.mode
    local first, last = 1, 0

    if mode == 'kh' then
      last = total - amount
    elseif mode == 'kl' then
      first, last = amount + 1, total
    elseif mode == 'dh' then
      first, last = total - amount + 1, total
    else
      last = amount
    end

    for i = first, last do
      dropped[remaining[i]] = true
    end
  end

  return dropped
end

--- Rolls a dice term and records it in the evaluation context.
-- @param node [Table dice node]
-- @param context [Table evaluation context]
-- @return [Number sum of the kept dice]
local function roll_term(node, context)
  local count = 1

  if node.count then
    count = evaluate_node(node.count, context)

    if !is_whole(count) or count < 0 or count > max_term_dice then
      fail('Dice count must be a whole number from 0 to '..max_term_dice, node.count.pos)
    end
  end

  context.dice = context.dice + count

  if context.dice > max_formula_dice then
    fail('Too many dice in formula (at most '..max_formula_dice..')', node.pos)
  end

  local low, high, label = -1, 1, 'F'

  if !node.fudge then
    local sides = evaluate_node(node.sides, context)

    if !is_whole(sides) or sides < 1 or sides > max_sides then
      fail('Dice must have a whole number of sides from 1 to '..max_sides, node.sides.pos)
    end

    low, high, label = 1, sides, sides
  end

  local explode = node.explode
  local threshold = explode == true and high or explode
  local explosions = 0
  local results = {}

  for _ = 1, count do
    local value = roll_die(node, low, high)

    results[#results + 1] = clamp_die(node, value)

    while threshold and value >= threshold and explosions < max_explosions do
      explosions = explosions + 1
      value = roll_die(node, low, high)
      results[#results + 1] = clamp_die(node, value)
    end
  end

  local dropped_indices = apply_keep(node, results)
  local kept, dropped = {}, {}
  local total = 0

  for i, value in ipairs(results) do
    if dropped_indices[i] then
      dropped[#dropped + 1] = value
    else
      kept[#kept + 1] = value
      total = total + value
    end
  end

  context.rolls[#context.rolls + 1] = {
    sides = label,
    results = results,
    kept = kept,
    dropped = dropped,
    total = total
  }

  return total
end

local function apply_binary(node, left, right)
  local op = node.op

  if op == '+' then
    return left + right
  elseif op == '-' then
    return left - right
  elseif op == '*' then
    return left * right
  elseif op == '/' then
    if right == 0 then
      fail('Division by zero', node.op_pos)
    end

    return left / right
  elseif op == '%' then
    if right == 0 then
      fail('Modulo by zero', node.op_pos)
    end

    return left % right
  end

  return left ^ right
end

local function apply_call(node, args)
  local name = node.name
  local value = args[1]

  if name == 'floor' then
    return math_floor(value)
  elseif name == 'ceil' then
    return math_ceil(value)
  elseif name == 'round' then
    return round(value)
  elseif name == 'abs' then
    return math_abs(value)
  end

  for i = 2, #args do
    if (name == 'min' and args[i] < value) or (name == 'max' and args[i] > value) then
      value = args[i]
    end
  end

  return value
end

--- Evaluates a syntax tree node, left to right.
-- @param node [Table syntax tree node]
-- @param context [Table evaluation context with `variables`, `rolls` and `dice`]
-- @return [Number the value]
evaluate_node = function(node, context)
  local kind = node.kind
  local value = nil

  if kind == 'number' then
    value = node.value
  elseif kind == 'group' then
    value = evaluate_node(node.expression, context)
  elseif kind == 'variable' then
    value = resolve_variable(context.variables, node)
  elseif kind == 'negate' then
    value = -evaluate_node(node.operand, context)
  elseif kind == 'binary' then
    local left = evaluate_node(node.left, context)
    local right = evaluate_node(node.right, context)

    value = apply_binary(node, left, right)
  elseif kind == 'call' then
    local args = {}

    for i, arg in ipairs(node.args) do
      args[i] = evaluate_node(arg, context)
    end

    value = apply_call(node, args)
  elseif kind == 'dice' then
    value = roll_term(node, context)
  else
    fail('Invalid dice formula node', node.pos or 1)
  end

  if !is_finite(value) then
    fail('Result is not a finite number', node.op_pos or node.pos)
  end

  return value
end

local function evaluate_formula(ast, variables)
  local context = { variables = variables, rolls = {}, dice = 0 }
  local total = evaluate_node(ast.expression, context)
  local rolls = context.rolls
  local natural = nil
  local critical = nil

  if total == 0 then
    total = 0
  end

  if #rolls > 0 then
    natural = 0

    for _, roll in ipairs(rolls) do
      natural = natural + roll.total
    end
  end

  if #rolls == 1 and rolls[1].sides == 20 and #rolls[1].kept == 1 then
    local face = rolls[1].kept[1]

    if face == 20 then
      critical = 'success'
    elseif face == 1 then
      critical = 'failure'
    end
  end

  return {
    total = total,
    formula = ast.formula,
    rolls = rolls,
    natural = natural,
    critical = critical
  }
end

--- Collects the dice nodes of a syntax tree in the order they are evaluated.
-- @param node [Table syntax tree node]
-- @param list [Table list the dice nodes are appended to]
-- @return [Table the list]
local function collect_dice(node, list)
  local kind = node.kind

  if kind == 'group' then
    collect_dice(node.expression, list)
  elseif kind == 'negate' then
    collect_dice(node.operand, list)
  elseif kind == 'binary' then
    collect_dice(node.left, list)
    collect_dice(node.right, list)
  elseif kind == 'call' then
    for _, arg in ipairs(node.args) do
      collect_dice(arg, list)
    end
  elseif kind == 'dice' then
    if node.count then
      collect_dice(node.count, list)
    end

    if node.sides then
      collect_dice(node.sides, list)
    end

    list[#list + 1] = node
  end

  return list
end

local function format_number(value)
  if is_whole(value) and math_abs(value) < 1e15 then
    return string_format('%d', value)
  end

  local text = string_format('%.2f', value)

  text = string_gsub(text, '0+$', '')
  text = string_gsub(text, '%.$', '')

  return text
end

--- Formats the dice of one term as a list, with dropped dice in brackets.
-- @param roll [Table roll entry of a result]
-- @return [String list such as '5, 4, 3, [1]']
local function format_roll(roll)
  local unused_drops = {}
  local parts = {}

  for _, value in ipairs(roll.dropped) do
    unused_drops[value] = (unused_drops[value] or 0) + 1
  end

  for _, value in ipairs(roll.results) do
    if (unused_drops[value] or 0) > 0 then
      unused_drops[value] = unused_drops[value] - 1
      parts[#parts + 1] = '['..format_number(value)..']'
    else
      parts[#parts + 1] = format_number(value)
    end
  end

  return table_concat(parts, ', ')
end

--- Parses a dice formula into a syntax tree that can be evaluated any number of times.
-- ```
-- local ast, err = Dice.parse('2d6kh1 + strength')
-- ```
-- @param formula [String dice formula]
-- @return [Table syntax tree, or nil and String error message naming the position]
function Dice.parse(formula)
  if !isstring(formula) then
    return nil, 'Dice formula must be a string'
  end

  local success, result = pcall(parse_formula, formula)

  if !success then
    return nil, error_message(result)
  end

  return result
end

--- Rolls a parsed formula.
-- The result has `total`, `formula` (as given), `rolls` (a list of
-- `{ sides, results, kept, dropped, total }` per dice term, in evaluation order, with `sides`
-- being 'F' for fudge dice), `natural` (sum of the kept dice of all terms, nil without dice) and
-- `critical` ('success' or 'failure' when the formula has a single d20 term that keeps one die
-- showing 20 or 1).
-- @param ast [Table syntax tree from Dice.parse]
-- @param variables=nil [Table/Function map of variable names to numbers, or function(name)
--   returning a number]
-- @return [Table result, or nil and String error message naming the position]
function Dice.evaluate(ast, variables)
  if !istable(ast) or ast.kind != 'formula' then
    return nil, 'Invalid dice formula syntax tree'
  end

  local success, result = pcall(evaluate_formula, ast, variables)

  if !success then
    return nil, error_message(result)
  end

  return result
end

--- Parses and rolls a dice formula.
-- ```
-- local result, err = Dice.roll('1d20 + 5')
-- print(result.total, result.natural, result.critical)
-- ```
-- @param formula [String dice formula]
-- @param variables=nil [Table/Function map of variable names to numbers, or function(name)
--   returning a number]
-- @return [Table result as described in Dice.evaluate, or nil and String error message]
function Dice.roll(formula, variables)
  local ast, err = Dice.parse(formula)

  if !ast then
    return nil, err
  end

  return Dice.evaluate(ast, variables)
end

--- Formats a result for display, listing every die after its term and the total at the end.
-- ```
-- Dice.format(Dice.roll('4d6kh3')) -- '4d6kh3 (5, 4, 3, [1]) = 12'
-- ```
-- @param result [Table result from Dice.roll or Dice.evaluate]
-- @return [String formatted roll]
function Dice.format(result)
  if !istable(result) or !isnumber(result.total) then
    return ''
  end

  local formula = tostring(result.formula or '')
  local total = format_number(result.total)
  local ast = Dice.parse(formula)

  if !ast then
    return formula..' = '..total
  end

  local rolls = result.rolls or {}
  local parts = {}
  local cursor = 1
  local insertions = {}

  for i, node in ipairs(collect_dice(ast.expression, {})) do
    if !rolls[i] then
      break
    end

    insertions[#insertions + 1] = { pos = node.finish, order = i, text = ' ('..format_roll(rolls[i])..')' }
  end

  table_sort(insertions, function(a, b)
    if a.pos == b.pos then
      return a.order < b.order
    end

    return a.pos < b.pos
  end)

  for _, insertion in ipairs(insertions) do
    parts[#parts + 1] = string_sub(formula, cursor, insertion.pos)
    parts[#parts + 1] = insertion.text
    cursor = insertion.pos + 1
  end

  parts[#parts + 1] = string_sub(formula, cursor)

  return string_match(table_concat(parts), '^%s*(.-)%s*$')..' = '..total
end

--- Formats a result like Dice.format, only shorter, for a line of chat: a term of one die
-- loses its count ('1d20' becomes 'd20'), and a formula that is a single die and nothing
-- else shows the die and the total alone, as the face and the total are the same number.
-- ```
-- Dice.format_compact(Dice.roll('1d20 + 3')) -- 'd20 (14) + 3 = 17'
-- Dice.format_compact(Dice.roll('1d20'))     -- 'd20 = 14'
-- Dice.format_compact(Dice.roll('4d6kh3'))   -- '4d6kh3 (5, 4, 3, [1]) = 12'
-- ```
-- @param result [Table result from Dice.roll or Dice.evaluate]
-- @return [String formatted roll]
function Dice.format_compact(result)
  local text = Dice.format(result)

  if text == '' then
    return text
  end

  text = string_gsub(text, '%f[%w]1([dD])([%d%%fF%(])', '%1%2')

  local die, face, total = string_match(text, '^([dD][%w%%]+) %(([^%(%)]+)%) = (%S+)$')

  if die and face == total then
    return die..' = '..total
  end

  return text
end

--- Checks whether a formula can be rolled.
-- Without variables only the syntax is checked. When variables are given, the formula is rolled
-- once with them, so that unknown variables, dice counts and sides out of range and divisions
-- by zero are reported as well.
-- @param formula [String dice formula]
-- @param variables=nil [Table/Function variable values to check against]
-- @return [Boolean whether the formula is valid, String error message when it is not]
function Dice.is_valid(formula, variables)
  local ast, err = Dice.parse(formula)

  if !ast then
    return false, err
  end

  if variables != nil then
    local result, roll_error = Dice.evaluate(ast, variables)

    if !result then
      return false, roll_error
    end
  end

  return true
end

--- Rolls plain dice without a formula.
-- @param sides [Number sides of each die]
-- @param count=1 [Number how many dice to roll]
-- @return [Number sum of the dice, 0 when the arguments are invalid]
function Dice.d(sides, count)
  sides = math_floor(tonumber(sides) or 0)
  count = math_floor(tonumber(count) or 1)

  if sides < 1 or sides > max_sides or count < 1 then
    return 0
  end

  local total = 0

  for _ = 1, math_min(count, max_term_dice) do
    total = total + math_random(1, sides)
  end

  return total
end
