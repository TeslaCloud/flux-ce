-- LUA HTML parser

class 'HTMLParser'

local empty_tags = {
  br = true,
  hr = true,
  img = true,
  embed = true,
  param = true,
  area = true,
  col = true,
  input = true,
  meta = true,
  link = true,
  base = true,
  basefont = true,
  frame = true,
  isindex = true
}

-- omittable tags siblings
-- if an open tag from the primary entry  follow
-- an unclosed tag of the secondary,
-- the secondary is automatically closed
-- See http://www.w3.org/TR/html5/syntax.html#optional-tags
local omittable_tags = {
  tbody = {
    thead = true,
    tbody = true,
    tfoot = true
  },
  thead = {
    thead = true,
    tbody = true,
    tfoot = true
  },
  tfoot = {
    thead = true,
    tbody = true,
    tfoot = true
  },
  td = {
    td = true,
    th = true
  },
  th = {
    td = true,
    th = true
  },
  tr = {
    tr = true
  },
  dd = {
    dd = true,
    dt = true
  },
  dt = {
    dd = true,
    dt = true
  },
  optgroup = {
    optgroup = true,
    option = true
  },
  optgroup = {
    optgroup = true,
    option = true
  },
  address = { p = true},
  article = { p = true},
  aside = { p = true},
  blockquote = { p = true},
  dir = { p = true},
  div = { p = true},
  dl = { p = true},
  fieldset = { p = true},
  footer = { p = true},
  form = { p = true},
  h1 = { p = true},
  h2 = { p = true},
  h3 = { p = true},
  h4 = { p = true},
  h5 = { p = true},
  h6 = { p = true},
  header = { p = true},
  hgroup = { p = true},
  hr = { p = true},
  menu = { p = true},
  nav = { p = true},
  ol = { p = true},
  p = { p = true},
  pre = { p = true},
  section = { p = true},
  table = { p = true},
  ul= { p = true}
}

-- omittable tags children
local omittable_tags2 = {
  table = {
    tr = true,
    td = true,
    p = true,
  },
  tr = {
    td = true,
    p = true
  },
  td = {
    p = true
  }
}

function HTMLParser:parse(data, lazy)
  local tree = {}
  local stack = {}
  local level = 0
  local new_level = 0
  table.insert(stack, tree)
  local node
  local lower_tag
  local script_open = false
  local script_val = ""
  local script_node = nil
  local tag_match = ""
  lazy = lazy or false

  for b, op, tag, attr, op2, bl1, val, bl2 in string.gmatch(
    data,
    "(<)(%/?!?)([%w:_%-'\\\"%[]+)(.-)(%/?%-?)>"..
    "([%s\r\n\t]*)([^<]*)([%s\r\n\t]*)"
  ) do
    lower_tag = string.lower(tag)

    if script_open then
      if lower_tag == "script" and op == "/" then
        node.child_nodes[1].value =   string.gsub(script_val, "^<!%[CDATA%[", "<!--//%1")
        if val != "" then
          table.insert(stack[level], {
            tag_name = "text_node",
            value = val
          })
        end
        level = level - 1
        script_open = false
      else
        script_val = script_val..b..op..tag..attr..op2..bl1..val..bl2
      end
    elseif op == "!" then
    elseif op == "/" then
      -- Check if the previous children elements end tag have been omitted
      -- and should be close automatically

      while !lazy
      and omittable_tags2[lower_tag]
      and #stack[level] > 0
      and omittable_tags2[lower_tag][stack[level][#stack[level]].tag_name]
      do
        level = level - 1
        table.remove(stack)
      end

      if level == 0 then return tree end

      if lower_tag != stack[level][#stack[level]].tag_name
      then
        error("Mismatch: "..lower_tag..
        ", (has "..stack[level][#stack[level]].tag_name..")")
      end

      level = level - 1
      table.remove(stack)
    else

      level = level + 1
      node = nil
      node = {}
      node.tag_name = lower_tag
      node.child_nodes = {}

      if attr != "" then
        node.attr = {}

        for n, v in string.gmatch(
          attr,
          "%s([^%s=]+)=\"([^\"]+)\""
        ) do
          node.attr[n] = string.gsub(v, '"', '[^\\]\\"')
        end

        for n, v in string.gmatch(
          attr,
          "%s([^%s=]+)='([^']+)'"
        ) do
          node.attr[n] = string.gsub(v, '"', '[^\\]\\"')
        end
      end

      if lower_tag == "script"
      and node.attr
      and !node.attr["src"]
      then
        script_val = bl1..val..bl2
        table.insert(node.child_nodes, {
          tag_name = "text_node",
          value = ""
        })

        table.insert(stack[level], node)
        script_open = true
      else
        -- Check if the previous sibling element end tag has been omitted
        -- and should be close automatically

        if !lazy
        and omittable_tags[lower_tag]
        and level > 1
        and stack[level-1]
        and #stack[level-1] > 0
        and omittable_tags[lower_tag][stack[level-1][#stack[level-1]].tag_name] == true
        then
          level = level - 1
          table.remove(stack)
          if level==0 then return tree end
        end

        table.insert(stack[level], node)

        if empty_tags[lower_tag] then
          if val != "" then
            table.insert(stack[level], {
              tag_name = "text_node",
              value = val
            })
          end
          node.child_nodes = nil
          level = level - 1
        else
          if val != "" then
            table.insert(node.child_nodes, {
              tag_name = "text_node",
              value = val
            })
          end
          table.insert(stack, node.child_nodes)
        end

      end
    end
  end
  if level!=0 then
    vlc.msg.dbg("Parse error: "..level)
  end
  collectgarbage()
  return tree
end

function HTMLParser:dump(data)
  local stack = {data}
  local d = ""
  local node = nil

  while #stack != 0 do
    node = nil
    node = stack[#stack][1]

    if !node then break end

    if node.tag_name == "text_node" then
      d = d..node.value:trim()
    else
      d = d.."\n"..string.rep (" ", #stack-1)
      d = d.."<"..node.tag_name

      if node.attr then
        for a, v in pairs(node.attr) do
          d = d.." "..a..'="'..v..'"'
        end
      end

      if empty_tags[node.tag_name] then
        d = d.."/>"
      else
        d = d..">"
      end
    end

    if node.child_nodes and #node.child_nodes > 0 then
      node.l = #node.child_nodes
      table.insert(stack, node.child_nodes)
    else
      table.remove(stack[#stack], 1)
      if node.child_nodes and #node.child_nodes == 0 and !empty_tags[node.tag_name] then
        d = d.."</"..node.tag_name..">"
      end
      while #stack > 0 and #stack[#stack] == 0 do
        table.remove(stack)
        if #stack > 0 then
          if stack[#stack][1].l > 1 then
            d = d.."\n"..string.rep(" ", #stack-1).."</"..stack[#stack][1].tag_name..">"
          else
            d = d.."</"..stack[#stack][1].tag_name..">"
          end
          table.remove(stack[#stack], 1)
        end
      end
    end
  end
  return d
end
