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
local http = require "luci.http"
local uci = luci.model.uci.cursor()
local docker = require "luci.model.docker"
local dk = docker.new()

local images = dk.images:list().body
local networks = dk.networks:list().body
local containers = dk.containers:list(nil, {all=true}).body

local urlencode = luci.http.protocol and luci.http.protocol.urlencode or luci.util.urlencode

function get_containers()
  local data = {}
  if type(containers) ~= "table" then return nil end
  for i, v in ipairs(containers) do
    local index = v.Created .. v.Id
    data[index]={}
    data[index]["_selected"] = 0
    data[index]["_id"] = v.Id:sub(1,12)
    data[index]["_name"] = v.Names[1]:sub(2)
    data[index]["_status"] = v.Status
    -- if v.Status:find("^Exited") then
    --   data[index]["_status"] = "Exited"
    -- end
    if (type(v.NetworkSettings) == "table" and type(v.NetworkSettings.Networks) == "table") then
      for networkname, netconfig in pairs(v.NetworkSettings.Networks) do
        data[index]["_network"] = (data[index]["_network"] ~= nil and (data[index]["_network"] .." | ") or "").. networkname .. (netconfig.IPAddress ~= "" and (": " .. netconfig.IPAddress) or "")
      end
    end
    -- networkmode = v.HostConfig.NetworkMode ~= "default" and v.HostConfig.NetworkMode or "bridge"
    -- data[index]["_network"] = v.NetworkSettings.Networks[networkmode].IPAddress or nil
    _, _, image = v.Image:find("^sha256:(.+)")
    if image ~= nil then
      image=image:sub(1,12)
    end
    if v.Ports then
      data[index]["_ports"] = nil
      for _,v2 in ipairs(v.Ports) do
        data[index]["_ports"] = (data[index]["_ports"] and (data[index]["_ports"] .. ", ") or "") .. (v2.PublicPort and (v2.PublicPort .. ":") or "")  .. (v2.PrivatePort and (v2.PrivatePort .."/") or "") .. (v2.Type and v2.Type or "")
      end
    end
    data[index]["_image"] = image or v.Image
    data[index]["_command"] = v.Command
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
container_selecter = c_table:option(Flag, "_selected","")
container_selecter.disabled = 0
container_selecter.enabled = 1
container_selecter.default = 0

container_id = c_table:option(DummyValue, "_id", translate("ID"))
container_name = c_table:option(DummyValue, "_name", translate("Name"))
container_name.template="cbi/dummyvalue"
container_name.href = function (self, section)
  return luci.dispatcher.build_url("admin/docker/container/" .. urlencode(container_id:cfgvalue(section)))
end
container_status = c_table:option(DummyValue, "_status", translate("Status"))
container_ip = c_table:option(DummyValue, "_network", translate("Network"))
container_ports = c_table:option(DummyValue, "_ports", translate("Ports"))
container_image = c_table:option(DummyValue, "_image", translate("Image"))
container_image.template="cbi/dummyvalue"
container_image.href = function (self, section)
  return luci.dispatcher.build_url("admin/docker/image/" .. urlencode(self:cfgvalue(section)))
end
container_command = c_table:option(DummyValue, "_command", translate("Command"))


container_selecter.write=function(self, section, value)
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

local start_stop_remove = function(m,cmd)
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
    m.message = ""
    for _,cont in ipairs(c_selected) do
      local msg = dk.containers[cmd](dk, cont)
      if msg.code >= 300 then
        m.message = m.message .."\n" .. msg.code..": "..msg.body.message
        luci.util.perror(msg.body.message)
      end
    end
    if m.message == "" then
      luci.http.redirect(luci.dispatcher.build_url("admin/docker/containers"))
    end
  end
end

action = m:section(Table,{{}})
action.notitle=true
action.rowcolors=false
action.template="cbi/nullsection"
btnnew=action:option(Button, "_new")
btnnew.inputtitle= translate("New")
btnnew.template="cbi/inlinebutton"
btnnew.inputstyle = "add"
btnstart=action:option(Button, "_start")
btnstart.template="cbi/inlinebutton"
btnstart.inputtitle=translate("Start")
btnstart.inputstyle = "apply"
btnrestart=action:option(Button, "_restart")
btnrestart.template="cbi/inlinebutton"
btnrestart.inputtitle=translate("Restart")
btnrestart.inputstyle = "reload"
btnstop=action:option(Button, "_stop")
btnstop.template="cbi/inlinebutton"
btnstop.inputtitle=translate("Stop")
btnstop.inputstyle = "reset"
btnremove=action:option(Button, "_remove")
btnremove.template="cbi/inlinebutton"
btnremove.inputtitle=translate("Remove")
btnremove.inputstyle = "remove"
btnnew.write = function(self, section)
  -- luci.template.render("admin_uci/apply", {
	-- 	changes = next(changes) and changes,
	-- 	configs = reload
  -- })
  luci.http.redirect(luci.dispatcher.build_url("admin/docker/newcontainer"))
end
btnstart.write = function(self, section)
  start_stop_remove(m,"start")
end
btnrestart.write = function(self, section)
  start_stop_remove(m,"restart")
end
btnremove.write = function(self, section)
  start_stop_remove(m,"remove")
end
btnstop.write = function(self, section)
  start_stop_remove(m,"stop")
end

return m