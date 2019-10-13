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

-- local images = dk.images:list().body
-- local networks = dk.networks:list().body



m=SimpleForm("docker", translate("Docker"))
m.template="docker/container"
m.container_name = arg[1]
m.container_info = {}
m.container_stats = {}
local response = dk.containers:inspect(m.container_name)
if response.code == 200 then
  m.container_info = response.body
else
  m.container_info = nil
end
response = dk.containers:stats(m.container_name, {stream=false})
if response.code == 200 then
  m.container_stats = response.body
else
  m.container_stats = nil
end


m.calculate_cpu_percent = function(d)
  if type(d) ~= "table" then return end
  cpu_count = tonumber(d["cpu_stats"]["online_cpus"])
  cpu_percent = 0.0
  cpu_delta = tonumber(d["cpu_stats"]["cpu_usage"]["total_usage"]) - tonumber(d["precpu_stats"]["cpu_usage"]["total_usage"])
    system_delta = tonumber(d["cpu_stats"]["system_cpu_usage"]) - tonumber(d["precpu_stats"]["system_cpu_usage"])
  if system_delta > 0.0 then
    cpu_percent = string.format("%.2f", cpu_delta / system_delta * 100.0 * cpu_count)
  end
  return cpu_percent .. "%"
end

m.get_memory = function(d)
  if type(d) ~= "table" then return end
  limit = string.format("%.2f", tonumber(d["memory_stats"]["limit"]) / 1024 / 1024)
  usage = string.format("%.2f", (tonumber(d["memory_stats"]["usage"]) - tonumber(d["memory_stats"]["stats"]["total_cache"])) / 1024 / 1024)
  return usage .. "MB / " .. limit.. "MB" 
end

m.get_rx_tx = function(d)
  if type(d) ~="table" then return end
  local data
  if type(d["networks"]) == "table" then
    for e, v in pairs(d["networks"]) do
      data = (data and (data .. "<br>") or "") .. e .. "  Total Tx:" .. string.format("%.2f",(tonumber(v.tx_bytes)/1024/1024)) .. "MB  Total Rx: ".. string.format("%.2f",(tonumber(v.rx_bytes)/1024/1024)) .. "MB"
    end
  end
  return data
end

m.get_ports = function(d)
  local data
  if d.NetworkSettings and d.NetworkSettings.Ports then
    for inter, out in pairs(d.NetworkSettings.Ports) do
      data = (data and (data .. "<br>") or "") .. out[1]["HostPort"] .. ":" .. inter 
    end
  end
  return data
end

m.get_env = function(d)
  local data
  if d.Config and d.Config.Env then
    for _,v in ipairs(d.Config.Env) do
      data = (data and (data .. "<br>") or "") .. v
    end
  end
  return data
end

m.get_command = function(d)
  local data
  if d.Config and d.Config.Cmd then
    for _,v in ipairs(d.Config.Cmd) do
      data = (data and (data .. " ") or "") .. v
    end
  end
  return data
end

m.get_mounts = function(d)
  local data
  if d.Mounts then
    for _,v in ipairs(d.Mounts) do
      data = (data and (data .. "<br>") or "") .. v["Source"] .. ":" .. v["Destination"] .. (v["Mode"] ~= "" and (":" .. v["Mode"]) or "")
    end
  end
  return data
end


m.get_links = function(d)
  local data
  if d.HostConfig and d.HostConfig.Links then
    for _,v in ipairs(d.HostConfig.Links) do
      data = (data and (data .. "<br>") or "") .. v
    end
  end
  return data
end

if luci.http.formvalue("status") == "1" then
  local rv = {
    uptime     = luci.sys.uptime(),
    localtime  = os.date(),
    loadavg    = { luci.sys.loadavg() },
    memtotal   = memtotal,
    memcached  = memcached,
    membuffers = membuffers,
    memfree    = memfree,
    swaptotal  = swaptotal,
    swapcached = swapcached,
    swapfree   = swapfree
  }
  luci.http.prepare_content("application/json")
  luci.http.write_json(rv)

  return
end
return m