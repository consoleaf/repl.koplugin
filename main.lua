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
local repl = require("myrepl")

local Repl = WidgetContainer:extend({
	name = "Repl",
	is_doc_only = false,
})

function Repl:onDispatcherRegisterActions()
	Dispatcher:registerAction("repl_action", { category = "none", event = "Repl", title = _("REPL"), general = true })
end

function Repl:init()
	self:onDispatcherRegisterActions()
	-- myrepl:setcontext("ui", self.ui)
	-- myrepl:setcontext("UIManager", UIManager)
end

---@param code string
---@param context_id? string
function Repl:repl(code, context_id)
	repl.repl_set_context_value("ui", self.ui, context_id)
	repl.repl_set_context_value("UIManager", self.ui, context_id)
	code = base64.decode(code)
	local res = repl.repl_evaluator(code, context_id)
	return res
end

return Repl
