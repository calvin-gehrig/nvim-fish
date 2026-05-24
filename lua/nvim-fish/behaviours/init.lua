-- nvim-fish/behaviours/init.lua — Behaviour registry and resolver

local M = {}

local presets = {
  horizontal = "nvim-fish.behaviours.horizontal",
  wander = "nvim-fish.behaviours.wander",
  sine = "nvim-fish.behaviours.sine",
  zigzag = "nvim-fish.behaviours.zigzag",
  target = "nvim-fish.behaviours.target",
}

--- Resolve a behaviour spec into a behaviour table.
--- @param spec string|table|function|nil
---   - string: preset name (e.g. "wander")
---   - table with [1] string: preset with opts (e.g. {"sine", amplitude=3})
---   - table with advance: raw behaviour object, returned as-is
---   - function: wrapped via custom_fn
---   - nil: defaults to "wander"
--- @return table behaviour with :advance() and optional :is_done()
function M.resolve(spec)
  if spec == nil then
    spec = "wander"
  end

  if type(spec) == "string" then
    local mod_path = presets[spec]
    if not mod_path then
      error("nvim-fish: unknown behaviour preset: " .. spec)
    end
    return require(mod_path).new()
  end

  if type(spec) == "function" then
    return require("nvim-fish.behaviours.custom_fn").new(spec)
  end

  if type(spec) == "table" then
    -- Raw behaviour object
    if spec.advance then
      return spec
    end
    -- Preset with opts: {"sine", amplitude = 3}
    if type(spec[1]) == "string" then
      local name = spec[1]
      local mod_path = presets[name]
      if not mod_path then
        error("nvim-fish: unknown behaviour preset: " .. name)
      end
      return require(mod_path).new(spec)
    end
    error("nvim-fish: invalid behaviour spec table")
  end

  error("nvim-fish: invalid behaviour spec type: " .. type(spec))
end

return M
