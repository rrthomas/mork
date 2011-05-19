-- Mork, the friendly alien
-- Turns ctypesgen JSON output into alien input
-- (c) Reuben Thomas 2011

module ("mork", package.seeall)

require "std"
require "alien"

local primitive_types = {
  char = "char",
  double = "double",
  float = "float",
  int = "int",
  void = "void",
  String = "string",
}

local function alien_lookup (id)
  local function lookup (id)
    return alien.default[id] -- FIXME: pass mork module to bind
  end
  local ok, func = pcall (lookup, id)
  return ok and func or nil
end

function bind (lib)
  local cmodule = {}

  local function real_type (ty)
    if ty.name then
      -- FIXME: Transitive closure
      return primitive_types[ty.name] or error ("unknown type `" .. tostring (ty) .. "'")
    elseif ty.argtypes then -- function
      return "callback"
    elseif ty.variety == "struct" then
      -- FIXME: Sometimes we still need this code, presumably only for anon structs
      -- local struct = {}
      -- for _, m in ipairs (ty.members) do
      --   table.insert (struct, {m[1], real_type (m[2])})
      -- end
      -- -- FIXME: Separate name spaces
      -- cmodule[ty.tag] = alien.defstruct (struct)
      primitive_types[ty.tag] = ty.tag
      return "void" -- FIXME: Do something better!
    elseif ty.variety == "union" then
      return "pointer" -- FIXME: Do something better!
    elseif ty.destination then -- pointer
      return "pointer" -- FIXME: Use ref types for one-level pointers, pointer otherwise
    elseif ty.base then -- array
      return "pointer" -- FIXME: Use alien arrays
    end
    error ("no real type for: " .. tostring (ty))
  end

  local converter = {
    constant =
    function (obj)
      -- FIXME: Implement
    end,

    enum =
    function (obj)
      -- FIXME: Implement
    end,

    variable =
    function (obj)
      -- FIXME: Implement
    end,

    ["function"] =
    function (obj)
      local func = alien_lookup (obj.name)
      if func then
        cmodule[obj.name] = func
        cmodule[obj.name]:types (real_type (obj["return"]), unpack (list.map (real_type, obj.args or {})))
      else
        print ("no such function `" .. obj.name .. "'")
      end
    end,

    struct =
    function (obj)
      -- FIXME: Move the definition to struct method
      local struct = {}
      for _, m in ipairs (obj.fields) do
        table.insert (struct, {m.name, real_type (m.ctype)})
      end
      -- FIXME: Separate name spaces
      cmodule[obj.name] = alien.defstruct (struct)
      primitive_types[obj.name] = obj.name
    end,

    union =
    function (obj)
      -- FIXME: Support unions
    end,

    typedef =
    function (obj)
      primitive_types[obj.name] = real_type (obj.ctype)
    end,

    macro_function =
    function (obj)
      -- FIXME: Implement
    end,

    macro =
    function (obj)
      -- FIXME: Implement
    end,
  }

  for _, obj in ipairs (lib) do
    if not converter[obj.type] then
      error ("bad object type `" .. obj.type .. "'")
    end
    converter[obj.type] (obj)
  end

  return cmodule
end
