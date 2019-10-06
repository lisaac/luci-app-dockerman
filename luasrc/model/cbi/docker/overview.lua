--[[
LuCI - Lua Configuration Interface
Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2005-2013 hackpascal <hackpascal@gmail.com>
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
    data[i]["name"] = v.Names[1]:sub(2)
    data[i]["status"] = v.Status
    if v.Status:find("^Exited") then
      data[i]["status"] = "Exited"
    end
    networkmode = v.HostConfig.NetworkMode ~= "default" and v.HostConfig.NetworkMode or "bridge"
    data[i]["ip"] = v.NetworkSettings.Networks[networkmode].IPAddress or nil
    _, _, image = v.Image:find("^sha256:(.+)")
    if image ~= nil then
      image=image:sub(1,12)
    end
    if v.Ports then
      data[i]["ports"] = ""
      for _,v2 in ipairs(v.Ports) do
        data[i]["ports"] = data[i]["ports"] .. ", " .. v2.PublicPort .. ":" .. v2.PrivatePort .."/".. v2.Type
      end
      data[i]["ports"]=data[i]["ports"]:sub(3)
    end
    data[i]["image"] = image or v.Image
    data[i]["command"] = v.Command
  end
  return data
end

m = SimpleForm("docker", translate("Docker"))
m.reset = false
m.submit = false
-- new Container
s = m:section(SimpleSection, " ", translate(" "))
s.addremove = true
s.anonymous = true

d = s:option(MultiValue, "new",translate(" "))
d:value("new", "New Container")
d = s:option(Value, "name", translate("Container Name"))
d.rmempty = true
d:depends("new", "new")
d = s:option(Value, "image", translate("Docker Image"))
d.rmempty = true
d:depends("new", "new")
for _, v in ipairs (images) do
  if v.RepoTags then
    d:value(v.RepoTags[1], v.RepoTags[1])
  end
end
d = s:option(Flag, "privileged", translate("Privileged"))
d.rmempty = true
d:depends("new", "new")
d = s:option(ListValue, "restart", translate("Restart policy"))
d.rmempty = true
d:depends("new", "new")
d:value("no", "No")
d:value("unless-stopped", "Unless stopped")
d:value("always", "Always")
d:value("on-failure", "On failure")
d.default = "unless-stopped"
d = s:option(ListValue, "network", translate("Networks"))
d:depends("new", "new")
d.rmempty = true
d.default = "bridge"

dip = s:option(Value, "ip", translate("IPv4"))
dip.datatype="ip4addr"
for _, v in ipairs (networks) do
  if v.Name then
    local parent = v.Options and v.Options.parent or nil
    local ip = v.IPAM and v.IPAM.Config and v.IPAM.Config[1] and v.IPAM.Config[1].Subnet or nil
    ipv6 =  v.IPAM and v.IPAM.Config and v.IPAM.Config[2] and v.IPAM.Config[2].Subnet or nil
    local network_name = v.Name .. " | " .. v.Driver  .. (parent and (" | " .. parent) or "") .. (ip and (" | " .. ip) or "").. (ipv6 and (" | " .. ipv6) or "")
    d:value(v.Name, network_name)

    if v.Name ~= "none" and v.Name ~= "bridge" and v.Name ~= "host" then
      dip:depends("network", v.Name)
    end

  end
end

d = s:option(DynamicList, "env", translate("Environmental Variable"))
d.placeholder = "TZ=Asia/Shanghai"
d.rmempty = true
d:depends("new", "new")
d = s:option(DynamicList, "mount", translate("Bind Mount"))
d.placeholder = "/media:/media:slave"
d.rmempty = true
d:depends("new", "new")
d = s:option(DynamicList, "port", translate("Exposed Ports"))
d.placeholder = "2200:22/tcp"
d.rmempty = true
d:depends("new", "new")
d = s:option(DynamicList, "links", translate("Links with other containers"))
d.placeholder = "redis3:redis"
d.rmempty = true
d:depends("new", "new")
d = s:option(Value, "command", translate("Run command"))
d.placeholder = "/bin/sh init.sh"
d.rmempty = true
d:depends("new", "new")
err = s:option(DummyValue, "_error", translate(" "))
err:depends("new", "new")
d = s:option(Button, "submit", translate("submit"))
d.rmempty = true
d:depends("new", "new")
d.inputstyle = "apply"


d.write = function(self, section)
  local tmp
  local name = self.map:get(section, "name")
  local image = self.map:get(section, "image")
  local privileged = self.map:get(section, "privileged")
  local restart = self.map:get(section, "restart")
  local env = self.map:get(section, "env")
  local network = self.map:get(section, "network") or "none"
  local ip = (network ~= "bridge" and network ~= "host" and network ~= "none") and self.map:get(section, "ip") or nil
  local mount = self.map:get(section, "mount")

  local portbindings = {}
  local exposedports = {}
  err.value = ""
  tmp = self.map:get(section, "port")
  for i, v in ipairs(tmp) do
    for v1 ,v2 in string.gmatch(v, "(%d+):([^%s]+)") do
      local _,_,p= v2:find("^%d+/(%w+)")
      if p == nil then
        v2=v2..'/tcp'
      end
      portbindings[v2] = {{HostPort=v1}}
      exposedports[v2] = {HostPort=v1}
    end
  end

  local links = self.map:get(section, "links")
  tmp = self.map:get(section, "command")
  local command = {}
  if tmp ~= nil then
    for v in string.gmatch(tmp, "[^%s]+") do 
      command[#command+1] = v
    end 
  end

  local create_body={
    Hostname = name,
    Domainname = "",
    Cmd = (#command ~= 0) and command or nil,
    Env = env,
    Image = image,
    Volumes = nil,
    ExposedPorts = (next(exposedports) ~= nil) and exposedports or nil,
    HostConfig = {
      Binds = (#mount ~= 0) and mount or nil,
      NetworkMode = network,
      RestartPolicy ={
        Name = restart,
        MaximumRetryCount = 0
      },
      Privileged = privileged and true or false,
      PortBindings = (next(portbindings) ~= nil) and portbindings or nil
    },
    NetworkingConfig = ip and {
      EndpointsConfig = {
        [network] = {
          IPAMConfig = {
            IPv4Address = ip
            }
        }
      }
    } or nil
  }
  local msg = dk.containers:create(name, nil, create_body)
  if msg.code == 201 then
    luci.http.redirect(luci.dispatcher.build_url(""))
  else
    err.description = string.format("<strong><font color=red>" .. msg.body.message .. "</font></strong>")
  end
end

-- list Containers


c_table = m:section(Table, get_containers(), translate(" "))
c_table.nodescr=true
-- v.template = "cbi/tblsection"
-- v.sortable = true
container_selected = c_table:option(Value, "selected",translate(" "))
container_selected.default = 0

container_name = c_table:option(DummyValue, "name", translate("Name"))
container_status = c_table:option(DummyValue, "status", translate("Status"))
container_ip = c_table:option(DummyValue, "ip", translate("IP"))
container_ports = c_table:option(DummyValue, "ports", translate("Ports"))
container_image = c_table:option(DummyValue, "image", translate("Image"))
container_command = c_table:option(DummyValue, "command", translate("Command"))

-- btnstart = c_table:option(Button, "start", translate("Start"))
-- btnstart.inputstyle = "apply"
btnconfiguration = c_table:option(Button, "configuration", translate("Configuration"))
btnconfiguration.inputstyle = "reload"
-- btnstop = c_table:option(Button, "stop", translate("Stop"))
-- btnstop.inputstyle = "reset"
-- btnremove = c_table:option(Button, "remove", translate("Remove"))
-- btnremove.inputstyle = "remove"
-- btnremove:depends("status", "Created")
-- btnremove:depends("status", "Exited")


-- btnstart.write = function(self, section)
--   if container_status:cfgvalue(section):find("^[UR]") then
--     if dk.containers:restart(container_name:cfgvalue(section)).code == 204 then
--       luci.http.redirect(luci.dispatcher.build_url("admin/system/docker/containers"))
--     else
--     end
--   else 
--     if dk.containers:start(container_name:cfgvalue(section)).code == 204 then
--       luci.http.redirect(luci.dispatcher.build_url("admin/system/docker/containers"))
--     else
--     end
--   end
-- end
btnconfiguration.write = function(self, section)
  luci.http.redirect(luci.dispatcher.build_url("admin/system/docker/container/" .. self.map:get(section, "selected")))
end

-- btnremove.write = function(self, section)
--   if container_status:cfgvalue(section):find("^[UR]") then
--   else
--     if dk.containers:remove(container_name:cfgvalue(section)).code == 204 then
--       luci.http.redirect(luci.dispatcher.build_url("admin/system/docker/containers"))
--     else
--     end
--   end
-- end

action = m:section(Table,{{}})
btnstart=action:option(Button, "_new", translate("New"))

btnstart=action:option(Button, "_start", translate("Start"))
btnstart.inputstyle = "apply"
btnstop=action:option(Button, "_stop", translate("Stop"))
btnstop.inputstyle = "reset"
btnremove=action:option(Button, "_remove", translate("Remove"))
btnremove.inputstyle = "remove"
dv=action:option(DummyValue, "dd", translate("Remove"))
action.notitle=true
action.rowcolors=false
action.nodescr=true
btnstop.write = function(self, section)

  local c_selected = {}
  local c_table_sids = c_table:cfgsections()
  -- dv.value= c_table_sids[1]
  for _, c_table_sid in ipairs(c_table_sids) do
    if container_selected:cfgvalue(c_table_sid) == "1" then
      dv.value= container_name:cfgvalue(c_table_sid)
      c_selected[#c_selected+1] = container_name:cfgvalue(c_table_sid)
    end
  end
  -- luci.http.redirect(luci.dispatcher.build_url("admin/system/docker/containers" .. c_selected[1]))
end


return m