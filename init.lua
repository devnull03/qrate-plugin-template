-- A qrate plugin, as small as one can usefully be: it flags cells that are longer than a length
-- you set, on the columns you switch it on for.
--
-- Everything here is a hook you can delete. `types/qrate.lua` lists every hook that exists, what
-- the host hands each one, and why — read that rather than guessing from this file. An editor
-- running luau-lsp will complete against it; see the README.
--
-- The table this file returns *is* the manifest. There is no other file the host reads.

local MAX = 120

return {
  -- The descriptor shape this plugin is written against. Leave it at 1 until qrate says otherwise;
  -- a version this build does not know is refused rather than half-loaded.
  api_version = 1,
  description = "Flags cells longer than a length you choose.",

  -- Knobs, rendered on this plugin's own Settings page. `project` travels with the .qrate file;
  -- `user` stays on this machine, which is where anything secret belongs.
  settings = {
    {
      key = "max",
      label = "Longest allowed",
      type = "text",
      scope = "project",
      description = "Cells longer than this are flagged. Blank uses " .. MAX .. ".",
    },
  },

  -- Right-click entries. `requires_settings` hides one until this plugin has stored something for
  -- what was clicked, which is how a "stop" entry avoids offering to undo nothing.
  menu = {
    { label = "Check length of this column", target = "column", command = "watch" },
    {
      label = "Stop checking length",
      target = "column",
      command = "forget",
      requires_settings = true,
    },
  },

  -- Runs when one of those entries is clicked. What it returns is stored: a field left out leaves
  -- that scope alone, and a field set replaces this plugin's whole object there — so read, modify,
  -- and hand the whole thing back rather than expecting a merge.
  on_command = function(command, ctx)
    if command == "forget" then
      return { column = {} }
    end
    print("watching " .. tostring(ctx.column))
    return { column = { watched = true } }
  end,

  -- Runs over one column whenever the grid settles, on every edit, off the UI thread. Answer what
  -- is wrong with the values; answer nothing at all for a column you were not asked about, because
  -- this is called for *every* column whether it concerns you or not.
  validate = function(column, values, settings)
    if not settings.column.watched then
      return {}
    end
    local max = tonumber(settings.project.max) or MAX

    local found = {}
    for row, value in ipairs(values) do
      if #value > max then
        found[#found + 1] = {
          row = row, -- 1-based, matching `values`
          severity = "warning", -- "error" | "warning" | "note"; missing reads as "error"
          message = column.name .. " is " .. #value .. " characters, over " .. max,
        }
      end
    end
    return found
  end,

  -- Other hooks, all optional and all described in `types/qrate.lua`:
  --
  --   permissions = { "net" }   ask the user before qrate.http will answer
  --   suggest = function(ctx)   completions under the cell being edited
  --   bar = { … }               an item in the status or title bar
  --   column_map = { … }        map each column onto a list you fetched
  --
  -- And the host functions: qrate.http, qrate.json, qrate.storage, qrate.status, plus `require`
  -- for another .lua file beside this one, and `print` into qrate's log.
}
