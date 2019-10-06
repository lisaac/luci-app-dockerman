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
local dk = docker.new()

local images = dk.images:list().body
local networks = dk.networks:list().body
local containers = dk.containers:list(nil, {all=true}).body

function get_containers()
  local data = {}
  for i, v in ipairs(containers) do
    data[i]={}
    data[i]["_selected"] = 0
    data[i]["_name"] = v.Names[1]:sub(2)
    data[i]["_status"] = v.Status
    -- if v.Status:find("^Exited") then
    --   data[i]["_status"] = "Exited"
    -- end
    if (type(v.NetworkSettings) == "table" and type(v.NetworkSettings.Networks) == "table") then
      for networkname, netconfig in pairs(v.NetworkSettings.Networks) do
        data[i]["_network"] = (data[i]["_network"] ~= nil and (data[i]["_network"] .." | ") or "").. networkname .. (netconfig.IPAddress ~= "" and (": " .. netconfig.IPAddress) or "")
      end
    end
    -- networkmode = v.HostConfig.NetworkMode ~= "default" and v.HostConfig.NetworkMode or "bridge"
    -- data[i]["_network"] = v.NetworkSettings.Networks[networkmode].IPAddress or nil
    _, _, image = v.Image:find("^sha256:(.+)")
    if image ~= nil then
      image=image:sub(1,12)
    end
    if v.Ports then
      data[i]["_ports"] = nil
      for _,v2 in ipairs(v.Ports) do
        data[i]["_ports"] = (data[i]["_ports"] and (data[i]["_ports"] .. ", ") or "") .. (v2.PublicPort and (v2.PublicPort .. ":") or "")  .. (v2.PrivatePort and (v2.PrivatePort .."/") or "") .. (v2.Type and v2.Type or "")
      end
    end
    data[i]["_image"] = image or v.Image
    data[i]["_command"] = v.Command
  end
  return data
end

local c_lists = get_containers()
-- list Containers
m = Map("docker", translate("Docker"))

c_table = m:section(Table, c_lists, translate("Containers"))
c_table.nodescr=true
-- v.template = "cbi/tblsection"
-- v.sortable = true
container_selected = c_table:option(Flag, "_selected","")
container_selected.disabled = 0
container_selected.enabled = 1
container_selected.default = 0

container_name = c_table:option(DummyValue, "_name", translate("Name"))
container_name.template="cbi/dummyvalue"
container_name.href = function (self, section)
  return luci.dispatcher.build_url("admin/docker/container/" .. self:cfgvalue(section))
end
container_status = c_table:option(DummyValue, "_status", translate("Status"))
container_ip = c_table:option(DummyValue, "_network", translate("Network"))
container_ports = c_table:option(DummyValue, "_ports", translate("Ports"))
container_image = c_table:option(DummyValue, "_image", translate("Image"))
container_name.template="cbi/dummyvalue"
container_image.href = function (self, section)
  -- self:cfgvalue(section):find("^([^%s]-)/([^%s]-)[:([^%s]+)]")
  image = self:cfgvalue(section):gsub("[/:]",".")
  return luci.dispatcher.build_url("admin/docker/image/" .. image)
end
container_command = c_table:option(DummyValue, "_command", translate("Command"))


container_selected.write=function(self, section, value)
  c_lists[section]._selected = value
end
--[[
  btnstart = c_table:option(Button, "start", translate("Start"))
  btnstart.inputstyle = "apply"
  btnconfiguration = c_table:option(Button, "_configuration", translate("Configuration"))
  btnconfiguration.inputstyle = "edit"
  btnstop = c_table:option(Button, "stop", translate("Stop"))
  btnstop.inputstyle = "reset"
  btnremove = c_table:option(Button, "remove", translate("Remove"))
  btnremove.inputstyle = "remove"
  btnremove:depends("status", "Created")
  btnremove:depends("status", "Exited")


  btnstart.write = function(self, section)
    if container_status:cfgvalue(section):find("^[UR]") then
      if dk.containers:restart(container_name:cfgvalue(section)).code == 204 then
        luci.http.redirect(luci.dispatcher.build_url("admin/system/docker/containers"))
      else
      end
    else 
      if dk.containers:start(container_name:cfgvalue(section)).code == 204 then
        luci.http.redirect(luci.dispatcher.build_url("admin/system/docker/containers"))
      else
      end
    end
  end
  btnconfiguration.write = function(self, section)
    luci.http.redirect(luci.dispatcher.build_url("admin/docker/container/" .. c_lists[section]._name))
  end

  btnremove.write = function(self, section)
    if container_status:cfgvalue(section):find("^[UR]") then
    else
      if dk.containers:remove(container_name:cfgvalue(section)).code == 204 then
        luci.http.redirect(luci.dispatcher.build_url("admin/system/docker/containers"))
      else
      end
    end
  end
]]

local start_stop_remove = function(cmd)
  local c_selected = {}
  -- 遍历table中sectionid
  local c_table_sids = c_table:cfgsections()
  for _, c_table_sid in ipairs(c_table_sids) do
    -- 得到选中项的名字
    if c_lists[c_table_sid]._selected == 1 then
      c_selected[#c_selected+1] = container_name:cfgvalue(c_table_sid)
    end
  end
  if #c_selected >0 then
    for _,cont in ipairs(c_selected) do
      dk.containers[cmd](dk, cont)
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/docker/containers"))
  end
end

action = m:section(Table,{{}})
action.template="cbi/inlinetable"
btnnew=action:option(Button, "_new", translate("New"))
btnnew.inputstyle = "add"
btnstart=action:option(Button, "_start", translate("Start"))
btnstart.inputstyle = "apply"
btnrestart=action:option(Button, "_restart", translate("Restart"))
btnrestart.inputstyle = "reload"
btnstop=action:option(Button, "_stop", translate("Stop"))
btnstop.inputstyle = "reset"
btnremove=action:option(Button, "_remove", translate("Remove"))
btnremove.inputstyle = "remove"
action.notitle=true
action.rowcolors=false
action.nodescr=true
btnnew.write = function(self, section)
  -- luci.template.render("admin_uci/apply", {
	-- 	changes = next(changes) and changes,
	-- 	configs = reload
  -- })
  luci.http.redirect(luci.dispatcher.build_url("admin/docker/newcontainer"))
end
btnstart.write = function(self, section)
  start_stop_remove("start")
end
btnrestart.write = function(self, section)
  start_stop_remove("restart")
end
btnremove.write = function(self, section)
  start_stop_remove("remove")
end
btnstop.write = function(self, section)
  start_stop_remove("stop")
end

return m