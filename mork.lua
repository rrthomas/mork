--- Mork, the friendly alien
-- <br>Turns ctypesgen JSON output into alien input
-- <br>© Reuben Thomas 2011
-- <br>Mork is distributed under the MIT license
module ("mork", package.seeall)

require "std"
require "alien"
require "json"

local primitive_types = {
  char = "char",
  double = "double",
  float = "float",
  int = "int",
  void = "void",
  String = "string",
}

--- Call ctypesgen on the given list of headers
-- @param lib name of library to use (FIXME: Allow multiple libs)
-- @param ... list of headers (FIXME: Find them on search path)
-- @return JSON binding
function generate_binding (lib, ...)
  return bind (lib, json.decode (io.shell ("ctypesgen.py --all-headers --builtin-symbols --no-stddef-types --no-gnu-types --output-language=json " ..
        table.concat ({...}, " "))))
end

--- Turn a ctypesgen description into a library binding
-- @param name name of library
-- @param desc ctypesgen description, decoded into a Lua table
-- @return a module of alien bindings
function bind (name, desc)
  local cmodule = {}
  local lib = alien.load (name)

  -- Look up a function in alien without raising an error
  local function alien_lookup (id)
    local function lookup (id)
      return lib[id]
    end
    local ok, func = pcall (lookup, id)
    return ok and func or nil
  end

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
        func:types (real_type (obj["return"]), unpack (list.map (real_type, obj.args or {})))
        cmodule[obj.name] = func
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

  for _, obj in ipairs (desc) do
    print (obj.name)
    if not converter[obj.type] then
      error ("bad object type `" .. obj.type .. "'")
    end
    converter[obj.type] (obj)
  end

  return cmodule
end
