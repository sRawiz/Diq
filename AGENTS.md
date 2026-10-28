# Diq development

## Runtime and scope
- Work directly on the Lua files in this repository using Codex. Roblox Studio and Studio MCP are not required for this workflow; do not configure them unless the user requests it.
- The current entry point is Main.lua, loaded on the client through an executor. Keep this runtime in mind rather than assuming a standard Studio LocalScript or server Script.
- Use the installed roblox-dev-skill for Luau language and standard Roblox API references. Its Studio placement and MCP workflows do not override the runtime described here.
- Distinguish standard Luau, Roblox client APIs, privileged Studio APIs, and executor-specific globals. Do not assume executor functions exist or behave identically across executors. Check capabilities where needed and report actionable failures.
- Keep existing module return values, public methods, and loading conventions compatible. Do not convert the project to Studio ModuleScripts unless requested.

## Reliability and review
- Preserve cleanup of event connections, tasks, GUI instances, and modified state. Repeated execution and character respawns should not accumulate handlers or leave stale state.
- For remote loading, distinguish download, compilation, and runtime errors. Keep downloaded source as untrusted code and avoid logging credentials or sensitive response bodies.
- Check current official Luau and Roblox documentation when an API or language detail is uncertain; use executor documentation or user-provided evidence for executor-specific behavior.
- Perform available static checks and inspect the diff. Clearly separate those checks from live Roblox/executor tests; never claim a live test was performed without evidence.
- Explain changes and testing limits to the user in Thai unless another language is requested.
