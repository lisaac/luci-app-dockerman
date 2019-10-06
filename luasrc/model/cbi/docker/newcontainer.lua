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


m = SimpleForm("docker", translate("Docker"))
m.redirect = luci.dispatcher.build_url("admin", "docker", "containers")
-- m.reset = false
-- m.submit = false
-- new Container
s = m:section(SimpleSection, translate("New Container"))
s.addremove = true
s.anonymous = true


d = s:option(Value, "name", translate("Container Name"))
d.rmempty = true
d = s:option(Value, "image", translate("Docker Image"))
d.rmempty = true

for _, v in ipairs (images) do
  if v.RepoTags then
    d:value(v.RepoTags[1], v.RepoTags[1])
  end
end
d = s:option(Flag, "privileged", translate("Privileged"))
d.rmempty = true

d = s:option(ListValue, "restart", translate("Restart policy"))
d.rmempty = true

d:value("no", "No")
d:value("unless-stopped", "Unless stopped")
d:value("always", "Always")
d:value("on-failure", "On failure")
d.default = "unless-stopped"
d = s:option(ListValue, "network", translate("Networks"))

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

d = s:option(DynamicList, "mount", translate("Bind Mount"))
d.placeholder = "/media:/media:slave"
d.rmempty = true

d = s:option(DynamicList, "port", translate("Exposed Ports"))
d.placeholder = "2200:22/tcp"
d.rmempty = true

d = s:option(DynamicList, "links", translate("Links with other containers"))
d.placeholder = "redis3:redis"
d.rmempty = true

d = s:option(Value, "command", translate("Run command"))
d.placeholder = "/bin/sh init.sh"
d.rmempty = true

d = s:option(Flag, "advance", translate("Advance"))
d.rmempty = true
d.disabled = 0
d.enabled = 1

d = s:option(Value, "cpus", translate("CPUs"), translate("Number of CPUs. Number is a fractional number. 0.000 means no limit."))
d.placeholder = "1.5"
d.rmempty = true
d:depends("advance", 1)

d = s:option(Value, "cpushares", translate("CPU Shares Weight"), translate("CPU shares (relative weight, if 0 is set, the system will ignore the value and use the default of 1024."))
d.placeholder = "1024"
d.rmempty = true
d:depends("advance", 1)

d = s:option(Value, "memory", translate("Memory"), translate("Memory limit (format: <number>[<unit>]). Number is a positive integer. Unit can be one of b, k, m, or g. Minimum is 4M."))
d.placeholder = "128m"
d.rmempty = true
d:depends("advance", 1)

d = s:option(Value, "blkioweight", translate("Block IO Weight"), translate("Block IO weight (relative weight) accepts a weight value between 10 and 1000."))
d.placeholder = "500"
d.rmempty = true
d:depends("advance", 1)

d = s:option(DynamicList, "tmpfs", translate("Tmpfs"), translate("Mount tmpfs filesystems"))
d.placeholder = "/run:rw,noexec,nosuid,size=65536k"
d.rmempty = true
d:depends("advance", 1)

local err = s:option(DummyValue, "_error", translate(" "))

m.handle = function(self, state, data)
  if state == FORM_VALID then
    local tmp
    local name = data.name
    local image = data.image
    local privileged = data.privileged
    local restart = data.restart
    local env = data.env
    local network = data.network
    local ip = (network ~= "bridge" and network ~= "host" and network ~= "none") and data.ip or nil
    local mount = data.mount
    local memory = data.memory or 0
    local cpushares = data.cpushares or 0
    local cpus = data.cpus or 0
    local blkioweight = data.blkioweight or 500
    
    local portbindings = {}
    local exposedports = {}
    local tmpfs = {}
    tmp = data.tmpfs
    for i, v in ipairs(tmp)do
      local _,_, k,v1 = v:find("(.-):(.+)")
      if k and v1 then
        tmpfs[k]=v1
      end
    end

    tmp = data.port
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

    local links = data.links
    tmp = data.command
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
        PortBindings = (next(portbindings) ~= nil) and portbindings or nil,
        Memory = memory,
        CpuShares = cpushares,
        NanoCPUs = cpus * 10 ^ 9,
        BlkioWeight = blkioweight,
        Tmpfs = tmpfs
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
      luci.http.redirect(luci.dispatcher.build_url("admin/docker/containers"))
    else
      err.description=string.format("<strong><font color=red>"..msg.message.."</font></strong>")
    end
  end
end

return m