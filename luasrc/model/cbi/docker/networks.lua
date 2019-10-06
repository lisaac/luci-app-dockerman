--[[
LuCI - Lua Configuration Interface
Copyright 2019 lisaac <lisaac.cn@gmail.com>
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
	http://www.apache.org/licenses/LICENSE-2.0
$Id$
]]--

require "luci.util"
local uci = luci.model.uci.cursor()
local docker = require "luci.docker"
local d = docker.new()

function get_networks()
  local networks = d.networks:list().body
  local data = {}
  for i, v in ipairs(networks) do
    data[i]={}
    data[i]["name"] = v.Name
    data[i]["driver"] = v.Driver
    if v.Driver == "bridge" then
      data[i]["interface"] = v.Options["com.docker.network.bridge.name"]
    elseif v.Driver == "macvlan" then
      data[i]["interface"] = v.Options.parent
    end
    data[i]["subnet"] = v.IPAM and v.IPAM.Config[1] and v.IPAM.Config[1].Subnet or nil
    data[i]["gateway"] = v.IPAM and v.IPAM.Config[1] and v.IPAM.Config[1].Gateway or nil
  end
  return data
end

m = Map("docker", translate("Docker"))

v = m:section(Table, get_networks(), translate("Networks"))

v:option(DummyValue, "name", translate("name"))
v:option(DummyValue, "driver", translate("Driver"))
v:option(DummyValue, "interface", translate("Interface"))
v:option(DummyValue, "subnet", translate("subnet"))
v:option(DummyValue, "gateway", translate("Gateway"))
v:option(Button, "remove", translate("Remove"))

return m