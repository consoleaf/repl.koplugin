--- This is a heavily modified version of https://github.com/YaroSpace/lua-console.nvim/blob/main/lua/lua-console/utils.lua

-- Global table to store REPL contexts. Each context will have its own environment,
-- user-defined variables, code buffer, and print buffer.
local _REPL_CONTEXTS = {}

if not setfenv then -- Lua 5.2 compatibility shim for getfenv/setfenv
	-- based on http://lua-users.org/lists/lua-l/2010-06/msg00314.html
	-- this assumes f is a function
	local function findenv(f)
		local level = 1
		repeat
			local name, value = debug.getupvalue(f, level)
			if name == "_ENV" then
				return level, value
			end
			level = level + 1
		until name == nil
		return nil
	end
	getfenv = function(f)
		return (select(2, findenv(f)) or _G)
	end
	setfenv = function(f, t)
		local level = findenv(f)
		if level then
			debug.setupvalue(f, level, t)
		end
		return f
	end
end

-- Assuming smatch is available in the environment, for example from KoReader.
-- If not, replace smatch with string.find appropriately.
-- local smatch = string.match -- If smatch is just an alias for match

-- Helper function: Converts a table of strings into a single string, joined by `sep`.
-- If the input is not a table, it's treated as a single-element table.
-- @param tbl table|string The table of strings to concatenate, or a single string.
-- @param sep string The separator to use (defaults to newline).
-- @return string The concatenated string.
local to_string = function(tbl, sep)
	tbl = tbl or {}
	sep = sep or "\n"

	if type(tbl) ~= "table" then
		tbl = { tbl }
	end

	return table.concat(tbl, sep)
end

-- Helper function: Converts a string into a table of lines.
-- If the input is already a table, it's returned as is.
-- @param obj string|table The string to split, or a table of strings.
-- @return table A table where each element is a line from the input string.
local to_table = function(obj)
	if type(obj) == "string" then
		local lines = {}
		-- Lua 5.1/LuaJIT compatible way to split by newline
		for line in obj:gmatch("([^\n]*)") do
			table.insert(lines, line)
		end
		return lines
	else
		return obj or {}
	end
end

--- Attempts to prepend 'return ' to a line to make it an expression return value.
--- This is used to make simple expressions (like '1+1') return their value.
--- This function operates on a *copy* of the lines.
--- @param lines table A table of code lines.
--- @return table A new table of lines with 'return ' possibly added to the last line.
local function try_add_return(lines)
	-- Create a shallow copy to avoid modifying the original lines
	local returned_lines = {}
	for i, v in ipairs(lines) do
		returned_lines[i] = v
	end

	local last_line_idx = #returned_lines
	if last_line_idx == 0 then
		return returned_lines
	end

	local last_line_content = returned_lines[last_line_idx] or ""

	-- Heuristic: If the last line appears to be a statement or part of a block,
	-- or already explicitly returning/printing, don't add 'return'.
	-- This list should be conservative.
	if
		last_line_content:match("^%s*function%s")
		or last_line_content:match("^%s*if%s")
		or last_line_content:match("^%s*for%s")
		or last_line_content:match("^%s*while%s")
		or last_line_content:match("^%s*repeat%s")
		or last_line_content:match("^%s*local%s")
		or last_line_content:match("^%s*end%s*$")
		or last_line_content:match("^%s*else%s")
		or last_line_content:match("^%s*elseif%s")
		or last_line_content:match("^%s*then%s")
		or last_line_content:match("^%s*do%s")
		or last_line_content:match("^%s*until%s")
		or last_line_content:match("^%s*return%s")
		or last_line_content:match("^%s*print%s*%(?.*%)?")
		or last_line_content:match("^%s*break%s*$")
		or last_line_content:match("^%s*goto%s")
	then
		return returned_lines
	end

	-- Attempt to add 'return'
	returned_lines[last_line_idx] = "return " .. last_line_content
	return returned_lines
end

--- Heuristically removes 'local' keyword from the start of lines.
--- WARNING: This is a simplified string-based heuristic and can fail
---          or break code in complex scenarios (e.g., 'local' inside strings, comments).
---          A proper implementation requires a Lua parser (like Tree-sitter).
--- @param lines table A table of code lines.
--- @return table A new table of lines with 'local ' potentially removed.
local function strip_local(lines)
	local stripped_lines = {}
	for _, line in ipairs(lines) do
		-- Only strip if 'local ' is at the very beginning or after only whitespace
		-- and followed by a word character or underscore (variable name)
		local new_line = line:gsub("^%s*local%s+", "", 1) -- Remove "local " including trailing space
		table.insert(stripped_lines, new_line)
	end
	return stripped_lines
end

--- Retrieves or creates a REPL context by its unique identifier.
--- Each context manages its own state (variables, code buffer, print output).
--- @param context_id any An identifier for the context (e.g., a unique string or number).
--- @return table The context object with `env`, `user_values`, `code_buffer`, `repl_print_buffer`.
local function get_or_create_context(context_id)
	local ctx = _REPL_CONTEXTS[context_id]
	if not ctx then
		ctx = {
			user_values = {},
			code_buffer = {},
			repl_print_buffer = {},
		}

		local env = {}
		local env_mt = {
			print = function(...)
				local results_str = {}
				for i = 1, select("#", ...) do
					local val = select(i, ...)
					table.insert(results_str, tostring(val))
				end
				table.insert(ctx.repl_print_buffer, table.concat(results_str, "\t"))
			end,
			__index = function(t, key)
				return rawget(t, key) or ctx.user_values[key] or _G[key]
			end,
			__newindex = function(_, k, v)
				ctx.user_values[k] = v
			end,
		}

		setmetatable(env, env_mt)
		env.print = env_mt.print

		ctx.env = env
		_REPL_CONTEXTS[context_id] = ctx
	end
	return ctx
end

--- Cleans up a Lua stack trace, removing internal REPL noise.
--- This is a heuristic that tries to make error messages more user-friendly.
--- @param error_msg string The raw error message (including stack trace).
--- @return string A cleaned-up version of the error message, potentially multi-line.
local function clean_stacktrace(error_msg)
	local lines = to_table(error_msg)
	local cleaned = {}
	for _, line in ipairs(lines) do
		if not line:find("^%[C%]: in function") then
			if not line:find("*REPL*") then
				table.insert(cleaned, line)
			end
		end
	end
	-- Fallback to original if cleaning yields empty string or only whitespace
	local cleaned_str = to_string(cleaned)
	if cleaned_str:match("^%s*$") then -- Check if it's empty or just whitespace
		return error_msg
	else
		return cleaned_str
	end
end

-- Assuming this function is globally available or imported in your KoReader environment
-- function smatch(str, pattern) ... end
local function detectcontinue(err)
	-- Use string.find for general Lua compatibility if smatch is not guaranteed.
	-- If smatch is part of KoReader's specific APIs, keep it.
	return (err and (err:find("'<eof>'$") or err:find("<eof>$")))
end
---
--- @class ReplResult
--- @field ret any[]|nil A table containing all return values from the executed chunk, or nil if none.
--- @field out string[] A table of strings captured from `print` calls during execution. Can be empty.
--- @field error string|nil An error message if execution or parsing failed. Can be 'code is incomplete' for incomplete input, or a general error string. Nil if no error.

--- Main REPL evaluator function. Takes a single line of code,
--- accumulates it, and evaluates the chunk if complete.
--- @param line string A single line of Lua code to evaluate.
--- @param context_id any? An optional identifier for the REPL context.
---                    If omitted, a default context (ID 1) is used.
--- @return ReplResult The result object
function repl_evaluator(line, context_id)
	context_id = context_id or 1 -- Default context ID if not provided

	local ctx = get_or_create_context(context_id)
	table.insert(ctx.code_buffer, line) -- Add the new line to the buffer

	local current_code_lines = ctx.code_buffer
	local result = { out = {} }

	local loaded_chunk = nil
	local load_error = nil

	-- Attempt 1: Try to load the code with `strip_local` and `add_return` (most eager for expression results)
	local code_attempt_1 = to_string(try_add_return(strip_local(current_code_lines)))
	loaded_chunk, load_error = load(code_attempt_1, "*REPL*", "t", ctx.env)
	if loaded_chunk then
		setfenv(loaded_chunk, ctx.env) -- Crucial for Lua 5.1/LuaJIT environment binding
	end

	-- If first attempt failed, try other forms
	if not loaded_chunk then
		-- Attempt 2: Try to load the code with `strip_local` only (for statements, function defs)
		local code_attempt_2 = to_string(strip_local(current_code_lines))
		loaded_chunk, load_error = load(code_attempt_2, "*REPL*", "t", ctx.env)
		if loaded_chunk then
			setfenv(loaded_chunk, ctx.env)
		end
	end

	-- Determine if `load_error` indicates an incomplete statement (continue).
	-- If loaded_chunk is not nil, it means it's complete, regardless of load_error.
	local should_continue = (not loaded_chunk and detectcontinue(load_error))

	-- If after all attempts, we don't have a loadable chunk.
	if not loaded_chunk then
		-- If it's incomplete, set a specific error message and DO NOT clear the buffer.
		if should_continue then
			result.error = "code is incomplete"
			-- ctx.code_buffer is NOT cleared, allowing more input.
		else
			-- It's a definitive syntax error (not incomplete). Clear the buffer.
			result.error = "Couldn't parse: \n" .. clean_stacktrace(load_error)
			ctx.code_buffer = {} -- Clear buffer on definitive syntax errors.
		end
		return result
	end

	-- If we reach here, `loaded_chunk` is a function ready for execution.
	-- Step 2: Execute the loaded chunk using `xpcall`.
	ctx.repl_print_buffer = {} -- Clear print buffer before this execution

	local xpcall_returns = { xpcall(loaded_chunk, function(err)
		return clean_stacktrace(err)
	end) }

	local xpcall_success = table.remove(xpcall_returns, 1)

	if xpcall_success then
		result.out = ctx.repl_print_buffer
		if #xpcall_returns > 0 then
			result.ret = xpcall_returns
		end
		ctx.code_buffer = {} -- Clear buffer on successful execution
	else
		result.error = "Error during execution: \n" .. xpcall_returns[1]
		ctx.code_buffer = {} -- Clear buffer on runtime error
	end

	return result
end

--- Sets a key-value pair directly into the specified REPL context's variables.
--- This allows external code to inject or modify variables in the REPL session.
--- @param key string The name of the variable to set.
--- @param value any The value to assign to the variable.
--- @param context_id any? The ID of the context to modify. Defaults to 1.
function repl_set_context_value(key, value, context_id)
	context_id = context_id or 1
	local ctx = get_or_create_context(context_id)
	ctx.user_values[key] = value
end

--- Clears (resets) a specific REPL context.
--- This will remove all accumulated code, user-defined variables, and clear print buffers
--- for the specified context ID.
--- @param context_id any? The ID of the context to clear. Defaults to 1.
function repl_clear_context(context_id)
	context_id = context_id or 1
	_REPL_CONTEXTS[context_id] = nil
end

return {
	repl_evaluator = repl_evaluator,
	repl_set_context_value = repl_set_context_value,
	repl_clear_context = repl_clear_context,
}
