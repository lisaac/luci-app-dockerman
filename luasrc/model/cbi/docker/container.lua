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
end
response = dk.containers:stats(m.container_name, {stream=false})
if response.code == 200 then
  m.container_stats = response.body
end

function calculate_cpu_percent(d)
  cpu_count = tonumber(d["cpu_stats"]["online_cpus"])
  cpu_percent = 0.0
  cpu_delta = tonumber(d["cpu_stats"]["cpu_usage"]["total_usage"]) - tonumber(d["precpu_stats"]["cpu_usage"]["total_usage"])
    system_delta = tonumber(d["cpu_stats"]["system_cpu_usage"]) - tonumber(d["precpu_stats"]["system_cpu_usage"])
  if system_delta > 0.0 then
    cpu_percent = cpu_delta / system_delta * 100.0 * cpu_count
  end
  return cpu_percent
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