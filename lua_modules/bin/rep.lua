#!/bin/sh

LUAROCKS_SYSCONFDIR='/etc/luarocks' exec '/usr/bin/lua5.4' -e 'package.path="/home/gulpy/projects/repl.koplugin/lua_modules/share/lua/5.4/?.lua;/home/gulpy/projects/repl.koplugin/lua_modules/share/lua/5.4/?/init.lua;"..package.path;package.cpath="/home/gulpy/projects/repl.koplugin/lua_modules/lib/lua/5.4/?.so;"..package.cpath;local k,l,_=pcall(require,"luarocks.loader") _=k and l.add_context("luarepl","0.10-1")' '/home/gulpy/projects/repl.koplugin/lua_modules/lib/luarocks/rocks-5.4/luarepl/0.10-1/bin/rep.lua' "$@"
