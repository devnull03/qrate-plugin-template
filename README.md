# qrate-plugin-template

A starting point for a [qrate](https://github.com/devnull03/qrate) plugin: the full type
definitions for the plugin API, and one small plugin that uses a handful of them.

The example flags cells longer than a length you set, on the columns you switch it on for. It is
deliberately dull — it exists so every hook has one worked instance you can delete.

## Starting a plugin

```sh
git clone <this repo> my-plugin
cd my-plugin
rm -rf .git && git init
```

Then drop the folder into qrate's plugins directory (**Help ▸ Open Plugins Folder**), or clone it
straight in there. Restart qrate, or toggle the plugin off and on in **Settings ▸ Plugins**.

**The folder name is the plugin's identity.** Its settings are stored under that name, so renaming
the folder later orphans whatever it had stored. Pick the name first.

## What is in here

| File | |
|---|---|
| `init.lua` | The plugin. The table it returns *is* the manifest — there is no other file the host reads. |
| `types/qrate.lua` | Type definitions for the whole plugin API, with the reasoning attached. |
| `.luaurc` | Points luau-lsp at `types/`. |

## Editor setup

Install [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) and open this folder. `types/qrate.lua`
declares every host function and every field a descriptor may carry, so completion tells you what
exists and typechecking tells you when you have the shape wrong.

That file is also the reference to read before writing anything. Luau's own `io`, `os` and `package`
are not loaded, so **a capability not declared there is one no plugin has** — which is much faster
to find out in an editor than at runtime.

It is never loaded when the plugin runs: qrate installs `qrate` as a global before it sandboxes the
VM, and there is no `require` path that reaches `types/`.

## Beyond one file

A plugin folder may contain other `.lua` files, and `init.lua` can `require("name")` any of them —
no path syntax, no `package`; the host reads the folder and a name resolves only against what it
found there. Split when one file stops being readable, not before.

## What a plugin can do

Declared in `init.lua`, all optional:

- `settings` — knobs on the plugin's own Settings page, in project or user scope. `password` is
  masked and refused in project scope, since the project file gets shared.
- `menu` — right-click entries on a cell, row, or column header.
- `bar` — an item in the status or title bar, whose text the plugin can change while it runs.
- `column_map` — map each of the project's columns onto a list the plugin fetched. Rendered twice,
  as a Settings picker and a column-header submenu, from the one declaration.
- `permissions` — `net` is the only one. The user grants it; until then `qrate.http` refuses.

Host functions: `qrate.http.get`, `qrate.json.decode`, `qrate.storage.get/set`, `qrate.status.set`,
plus `require` and `print` (which writes to qrate's session log — a packaged build has no console,
so it is the only `print` anybody will read).

Entry points: `validate` (what is wrong with a column), `on_command` (a menu or bar click), and
`suggest` (completions under the cell being edited).

## A real one

[`qrate-islandora`](../qrate/plugins/islandora) checks columns against an Islandora site's
controlled vocabularies. It uses the network, per-plugin storage, credentials, a column map, and
suggestions — worth reading once you have outgrown this template.

> `types/qrate.lua` is a copy, not a shared dependency: Luau has no package manager and a plugin is
> a folder somebody drops in by hand. When qrate's API version rises, take a fresh copy.
