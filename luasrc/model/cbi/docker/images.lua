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

function get_images()
  local images = d.images:list().body
  local data = {}
  for i, v in ipairs(images) do
    data[i]={}
    data[i]["id"] = v.Id
    data[i]["containers"] = tostring(v.Containers)
    if v.RepoTags then
      data[i]["tags"] = v.RepoTags[1]
    else 
      _,_, data[i]["tags"] = v.RepoDigests[1]:find("^(.-)@.+")
      data[i]["tags"]=data[i]["tags"]..":none"
    end
    data[i]["size"] = string.format("%.2f", tostring(v.Size/1024/1024)).."MB"
    data[i]["created"] = os.date("%Y/%m/%d %H:%M:%S",v.Created)
  end
  return data
end

m = Map("docker", translate("Docker"))

v = m:section(Table, get_images(), translate("Images"))

v:option(DummyValue, "id", translate("ID"))
v:option(DummyValue, "containers", translate("Containers"))
v:option(DummyValue, "tags", translate("RepoTags"))
v:option(DummyValue, "size", translate("Size"))
v:option(DummyValue, "created", translate("Created"))

v:option(Button, "remove", translate("Remove"))

return m