-- Copyright (c) 2011-2015 Rob Hoelz <rob@hoelz.ro>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
-- the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
-- FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
-- COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
-- IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- This is a modified copy of repl.sync

-- Add the local lua_modules directory to package.path
package.path = "./lua_modules/share/lua/5.4/?.lua;" .. "./lua_modules/share/lua/5.4/?/init.lua;" .. package.path
package.path = "plugins/repl.koplugin/lua_modules/share/lua/5.4/?.lua;"
	.. "plugins/repl.koplugin/lua_modules/share/lua/5.4/?/init.lua;"
	.. package.path

local repl = require("repl")
local sync_repl = repl:clone()
local error = error

-- @class repl.sync
--- This module implements a synchronous REPL.  It provides
--- a run() method for actually running the REPL, and requires
--- that implementors implement the lines() method.

-- --- Run a REPL loop in a synchronous fashion.
-- -- @name repl.sync:run
-- function sync_repl:run()
--   self:prompt(1)
--   for line in self:lines() do
--     local level = self:handleline(line)
--     self:prompt(level)
--   end
--   self:shutdown()
-- end

--- Returns an iterator that yields lines to be evaluated.
-- @name repl.sync:lines
-- @return An iterator.
function sync_repl:lines()
	error("You must implement the lines method")
end

sync_repl.results = ""
sync_repl.error = ""
sync_repl.output = {}
sync_repl.chunk_env = {}

function sync_repl:displayresults(results)
	sync_repl.results = results
end

function sync_repl:displayerror(err)
	sync_repl.error = err
end

function sync_repl:getcontext()
	local context = _G
	local chunk_env = setmetatable({}, { __index = context })

	-- Override 'print' within this specific chunk environment
	chunk_env.print = function(...)
		local args_to_string = {}
		for i, v in ipairs({ ... }) do
			-- Convert arguments to string, separated by tab like default print
			args_to_string[i] = tostring(v)
		end
		table.insert(sync_repl.output, table.concat(args_to_string, "\t"))
	end

	for key, value in pairs(self.chunk_env) do
		chunk_env[key] = value
	end

	-- Return this modified environment for chunk execution
	return chunk_env
end

---@param key string
---@param value any
function sync_repl:setcontext(key, value)
	self.chunk_env[key] = value
end

return sync_repl
