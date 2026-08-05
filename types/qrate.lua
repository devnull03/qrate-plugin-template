--!strict
-- Type definitions for the `qrate` plugin API, as of api_version 1.
--
-- This file is never loaded at runtime — the host installs `qrate` as a global before it sandboxes
-- the VM, and there is no `require` path that would reach here. It exists so an editor running
-- luau-lsp can complete and typecheck a plugin; see `.luaurc`.
--
-- Everything the host gives a plugin arrives through this global or through the descriptor the
-- script returns. There is no other surface: Luau's own `io`, `os` and `package` are not loaded,
-- so a capability that is not here is one the plugin does not have.

-- ---------------------------------------------------------------------------------------------
-- Host functions
-- ---------------------------------------------------------------------------------------------

export type Response = {
	status: number,
	body: string,
}

export type Account = {
	username: string?,
	password: string?,
}

export type RequestOptions = {
	--- Sent as HTTP basic auth. A blank or missing pair is the same as sending none, so a plugin
	--- needs one code path whether or not the user has filled its credential settings in.
	auth: Account?,
}

export type Http = {
	--- GET `url`. Answers the response, or `nil` and a message — an unreachable server is a thing
	--- to report, not to crash on.
	---
	--- Requires the `net` permission: declared by the plugin, granted by the user in
	--- Settings ▸ Plugins. Ungranted, this answers `nil` and says so.
	---
	--- The host owns the timeout, the TLS policy and the redirect policy. Calls are rate limited
	--- per plugin, and a refusal costs a request too — a loop against a dead server cannot spin.
	get: (url: string, options: RequestOptions?) -> (Response?, string?),
}

export type Json = {
	--- Parse JSON. Answers a table, or `nil` and a message: a server that returns an error page or
	--- a bot-check instead of JSON is common enough to be handled rather than raised.
	---
	--- JSON `null` arrives as `nil`, so a missing field and an explicitly null one read the same.
	decode: (text: string) -> (any?, string?),
}

export type Status = {
	--- Retitle one of this plugin's own declared bar items. Buffered, not applied: a plugin runs
	--- off the UI thread, and the text lands when the call returns.
	---
	--- `text` carries inline markup: `**bold**`, `~~strike~~`, `[red]…[/]`, `[green]…[/]`.
	set: (id: string, text: string) -> (),
}

export type Storage = {
	--- This plugin's own cache, kept beside qrate's data and *not* in the project file — what a
	--- plugin caches is about this machine, and a project file is a thing people commit.
	---
	--- Survives a restart. Written out by the host after a call that changed it.
	get: (key: string) -> any?,
	set: (key: string, value: any) -> (),
}

export type Qrate = {
	http: Http,
	json: Json,
	status: Status,
	storage: Storage,
}

declare qrate: Qrate

--- Load a sibling `.lua` file from this plugin's own folder, and nothing else. Evaluated once
--- however many times it is required. There is no path syntax: the host reads the folder and a
--- name resolves only against what it found.
declare function require(name: string): any

--- Writes to qrate's session log, tagged with this plugin's name. A packaged build has no console,
--- so this is the only `print` that anybody will ever read.
declare function print(...: any): ()

-- ---------------------------------------------------------------------------------------------
-- What the host hands a plugin
-- ---------------------------------------------------------------------------------------------

--- App-wide values a plugin has to agree with rather than restate.
export type AppSettings = {
	--- What separates several values inside one cell, e.g. `;` in `Film; Video`. Empty means the
	--- cell is one indivisible value. Set by the user in Settings ▸ Columns — split cells with
	--- this, or the plugin will disagree with the column filter the user can see.
	subdelimiter: string,
}

--- This plugin's own stored objects, and nobody else's. A scope with nothing stored arrives as an
--- empty table rather than `nil`, so reads need no guard.
export type Settings = {
	--- Written by commands and by the mapping tool, per column, into the project file.
	column: any,
	--- Project scope: stored in the `.qrate` file, so it travels with the project.
	project: any,
	--- User scope: stored per machine. Where credentials belong — a `password` setting is refused
	--- in project scope, because a project file gets shared.
	user: any,
	app: AppSettings,
}

export type Column = {
	--- Header text. Also the name findings are filed under.
	name: string,
	--- The column's declared type from the project, or empty if unconfigured.
	data_type: string,
}

export type Severity = "error" | "warning" | "note"

export type Finding = {
	--- 1-based, matching the `values` array this came from.
	row: number,
	--- Missing reads as `"error"`.
	severity: Severity?,
	message: string,
}

--- What was clicked, handed to `on_command`.
export type CommandContext = {
	--- Header text, or `nil` when the command came from a bar item with nothing selected.
	column: string?,
	--- 1-based, when a single cell was clicked.
	row: number?,
	--- Every row's text for this column, in source order.
	values: { string },
	--- The option a mapping menu entry carried, when the command came from one.
	argument: string?,
	settings: Settings,
}

--- What the user is typing, handed to `suggest`.
export type SuggestContext = {
	column: string?,
	row: number?,
	--- The text in the cell being edited, as it stands.
	prefix: string?,
	settings: Settings,
}

-- ---------------------------------------------------------------------------------------------
-- The descriptor: the table a plugin's `init.lua` returns
-- ---------------------------------------------------------------------------------------------

export type SettingScope = "user" | "project"
export type SettingKind = "switch" | "text" | "password"

export type SettingSpec = {
	--- Names a field inside this plugin's own object in `scope`, which is what `validate` reads
	--- back as `settings.user[key]` or `settings.project[key]`.
	key: string,
	label: string,
	description: string?,
	scope: SettingScope,
	--- `password` is masked in Settings and refused in project scope.
	type: SettingKind,
}

export type MenuTarget = "column" | "cell" | "row"

export type MenuItem = {
	label: string,
	target: MenuTarget,
	--- Passed back to `on_command` verbatim.
	command: string,
	--- Show the entry only when this plugin already has settings stored for what was clicked — a
	--- "Clear…" entry needs something to clear.
	requires_settings: boolean?,
}

export type BarActionMenuEntry = { label: string, command: string }

--- One mouse button on a bar item: either a command, or a menu. Not both.
export type BarAction = {
	command: string?,
	menu: { BarActionMenuEntry }?,
}

export type BarItem = {
	--- Plugin-local; what `qrate.status.set` addresses.
	id: string,
	bar: "status" | "title",
	side: "left" | "right",
	text: string,
	tooltip: string?,
	left: BarAction?,
	right: BarAction?,
}

--- Maps each of the project's columns onto something this plugin holds a list of.
---
--- Declared once and rendered twice: as a per-column picker on this plugin's Settings page, and as
--- a checkable submenu on the column header. Both write to the same place, so the two cannot
--- disagree.
---
--- No plugin code runs to draw either. The options are whatever this plugin last stored under
--- `options`, which is what lets a list fetched from a server appear in a menu that has to be
--- built while the user waits.
export type ColumnMapSpec = {
	--- Field written into each column's own bucket, read back as `settings.column[key]`.
	key: string,
	label: string,
	description: string?,
	--- Key in this plugin's *project-scope* object holding the options, as either plain strings or
	--- `{ value = …, label = … }` pairs.
	options: string,
	--- Command that repopulates that list. Run when the user clicks Refresh.
	refresh: string,
	--- Whether a column may carry several options at once.
	multiple: boolean?,
}

--- What a command asks the host to store. A field left out leaves that scope alone; a field set
--- **replaces** this plugin's whole object there, so read-modify-write rather than assuming a merge.
export type Writes = {
	column: any?,
	project: any?,
	user: any?,
}

--- The table `init.lua` returns. There is no manifest: this *is* the manifest.
---
--- At least one of `validate`, `on_command` or `suggest` has to be here, or the plugin does
--- nothing and is refused at load.
export type Plugin = {
	--- The descriptor shape this plugin is written against. Missing reads as 1. A version above
	--- what the running qrate speaks is refused, with both numbers named.
	api_version: number?,
	--- Overrides the folder name as this plugin's identity — which is what its stored settings are
	--- keyed by, so renaming orphans whatever it had stored.
	name: string?,
	--- One line, shown on the Settings page.
	description: string?,
	--- What this plugin needs to be allowed to do. `net` is the only one. The user grants it in
	--- Settings ▸ Plugins; until then, `qrate.http` refuses and says so.
	permissions: { string }?,

	settings: { SettingSpec }?,
	menu: { MenuItem }?,
	bar: { BarItem }?,
	column_map: ColumnMapSpec?,

	--- Runs over one column's values whenever the grid settles. Answers what is wrong with them.
	---
	--- Runs off the UI thread, so it may block on a server — but it runs on *every* edit, so
	--- anything expensive belongs in a command or behind `qrate.storage`.
	validate: ((column: Column, values: { string }, settings: Settings) -> { Finding })?,

	--- Runs when one of this plugin's menu entries or bar buttons is clicked.
	on_command: ((command: string, ctx: CommandContext) -> Writes?)?,

	--- Offers completions for the cell being edited. The host debounces and drops answers that a
	--- newer keystroke has superseded, so this may be as slow as one request.
	suggest: ((ctx: SuggestContext) -> { string })?,
}

return nil
