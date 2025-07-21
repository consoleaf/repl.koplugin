--[[--
REPL plugin for https://github.com/Consoleaf/kopl

@module koplugin.Repl
--]]
--

local Dispatcher = require("dispatcher") -- luacheck:ignore
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Event = require("ui/event")

package.path = "./lua_modules/share/lua/5.4/?.lua;" .. "./lua_modules/share/lua/5.4/?/init.lua;" .. package.path
package.path = "plugins/repl.koplugin/lua_modules/share/lua/5.4/?.lua;"
	.. "plugins/repl.koplugin/lua_modules/share/lua/5.4/?/init.lua;"
	.. package.path

local base64 = require("base64")
local myrepl = require("myrepl")

local Repl = WidgetContainer:extend({
	name = "Repl",
	is_doc_only = false,
})

function Repl:onDispatcherRegisterActions()
	Dispatcher:registerAction("repl_action", { category = "none", event = "Repl", title = _("REPL"), general = true })
end

function Repl:init()
	self:onDispatcherRegisterActions()
	myrepl:setcontext("ui", self.ui)
end

---@param code string
function Repl:repl(code)
	code = base64.decode(code)
	local res = myrepl:handleline(code)
	if res == 2 then
		return { error = "code is incomplete" }
	end
	local out = myrepl.output
	local results = myrepl.results
	myrepl.output = {}
	myrepl.results = ""
	myrepl.error = ""
	self:clean()
	return { ret = results, out = out, error = myrepl.error }
end

function Repl:clean()
	myrepl._buffer = ""
end

return Repl
