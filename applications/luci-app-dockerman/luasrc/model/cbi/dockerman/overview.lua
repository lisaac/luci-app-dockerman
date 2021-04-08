--[[
LuCI - Lua Configuration Interface
Copyright 2019 lisaac <https://github.com/lisaac/luci-app-dockerman>
]]--

local docker = require "luci.model.docker"
local uci = require "luci.model.uci"

local m, s, o

function byte_format(byte)
	local suff = {"B", "KB", "MB", "GB", "TB"}
	for i=1, 5 do
		if byte > 1024 and i < 5 then
			byte = byte / 1024
		else
			return string.format("%.2f %s", byte, suff[i])
		end
	end
end

m = Map("dockerd", translate("Docker"),
	translate("DockerMan is a Simple Docker manager client for LuCI, If you have any issue please visit:") ..
	" " ..
	[[<a href="https://github.com/lisaac/luci-app-dockerman" target="_blank">]] ..
	translate("Github") ..
	[[</a>]])

local docker_info_table = {}
-- docker_info_table['0OperatingSystem'] = {_key=translate("Operating System"),_value='-'}
-- docker_info_table['1Architecture'] = {_key=translate("Architecture"),_value='-'}
-- docker_info_table['2KernelVersion'] = {_key=translate("Kernel Version"),_value='-'}
docker_info_table['3ServerVersion'] = {_key=translate("Docker Version"),_value='-'}
docker_info_table['4ApiVersion'] = {_key=translate("Api Version"),_value='-'}
docker_info_table['5NCPU'] = {_key=translate("CPUs"),_value='-'}
docker_info_table['6MemTotal'] = {_key=translate("Total Memory"),_value='-'}
docker_info_table['7DockerRootDir'] = {_key=translate("Docker Root Dir"),_value='-'}
docker_info_table['8IndexServerAddress'] = {_key=translate("Index Server Address"),_value='-'}
docker_info_table['9RegistryMirrors'] = {_key=translate("Registry Mirrors"),_value='-'}

s = m:section(Table, docker_info_table)
s:option(DummyValue, "_key", translate("Info"))
s:option(DummyValue, "_value")

s = m:section(SimpleSection)
s.template = "dockerman/overview"

s.containers_running = '-'
s.images_used = '-'
s.containers_total = '-'
s.images_total = '-'
s.networks_total = '-'
s.volumes_total = '-'

-- local socket = luci.model.uci.cursor():get("dockerd", "dockerman", "socket_path")
if docker.new():_ping().code == 200 then
	local dk = docker.new()
	local containers_list = dk.containers:list({query = {all=true}}).body
	local images_list = dk.images:list().body
	local vol = dk.volumes:list()
	local volumes_list = vol and vol.body and vol.body.Volumes or {}
	local networks_list = dk.networks:list().body or {}
	local docker_info = dk:info()

	-- docker_info_table['0OperatingSystem']._value = docker_info.body.OperatingSystem
	-- docker_info_table['1Architecture']._value = docker_info.body.Architecture
	-- docker_info_table['2KernelVersion']._value = docker_info.body.KernelVersion
	docker_info_table['3ServerVersion']._value = docker_info.body.ServerVersion
	docker_info_table['4ApiVersion']._value = docker_info.headers["Api-Version"]
	docker_info_table['5NCPU']._value = tostring(docker_info.body.NCPU)
	docker_info_table['6MemTotal']._value = byte_format(docker_info.body.MemTotal)
	if docker_info.body.DockerRootDir then
		local statvfs = nixio.fs.statvfs(docker_info.body.DockerRootDir)
		local size = statvfs and (statvfs.bavail * statvfs.bsize) or 0
		docker_info_table['7DockerRootDir']._value = docker_info.body.DockerRootDir .. " (" .. tostring(byte_format(size)) .. " " .. translate("Available") .. ")"
	end

	docker_info_table['8IndexServerAddress']._value = docker_info.body.IndexServerAddress
	for i, v in ipairs(docker_info.body.RegistryConfig.Mirrors) do
		docker_info_table['9RegistryMirrors']._value = docker_info_table['9RegistryMirrors']._value == "-" and v or (docker_info_table['9RegistryMirrors']._value .. ", " .. v)
	end

	s.images_used = 0
	for i, v in ipairs(images_list) do
		for ci,cv in ipairs(containers_list) do
			if v.Id == cv.ImageID then
				s.images_used = s.images_used + 1
				break
			end
		end
	end

	s.containers_running = tostring(docker_info.body.ContainersRunning)
	s.images_used = tostring(s.images_used)
	s.containers_total = tostring(docker_info.body.Containers)
	s.images_total = tostring(#images_list)
	s.networks_total = tostring(#networks_list)
	s.volumes_total = tostring(#volumes_list)
end

s = m:section(NamedSection, "dockerman", "section", translate("Setting"))

o = s:option(Flag, "remote_endpoint",
	translate("Remote Endpoint"),
	translate("Connect to remote endpoint"))
o.rmempty = false

o = s:option(Value, "socket_path",
	translate("Docker Socket Path"))
o.default = "/var/run/docker.sock"
o.placeholder = "/var/run/docker.sock"
o:depends("remote_endpoint", 0)

o = s:option(Value, "remote_host",
	translate("Remote Host"))
o.placeholder = "10.1.1.2"
o:depends("remote_endpoint", 1)

o = s:option(Value, "remote_port",
	translate("Remote Port"))
o.placeholder = "2375"
o.default = "2375"
o:depends("remote_endpoint", 1)

-- o = s:taboption("dockerman", Value, "status_path", translate("Action Status Tempfile Path"), translate("Where you want to save the docker status file"))
-- o = s:taboption("dockerman", Flag, "debug", translate("Enable Debug"), translate("For debug, It shows all docker API actions of luci-app-dockerman in Debug Tempfile Path"))
-- o.enabled="true"
-- o.disabled="false"
-- o = s:taboption("dockerman", Value, "debug_path", translate("Debug Tempfile Path"), translate("Where you want to save the debug tempfile"))

if nixio.fs.access("/usr/bin/dockerd") then
	o = s:option(DynamicList, "ac_allowed_interface", translate("Allowed access interfaces"), translate("Which interface(s) can access containers under the bridge network, fill-in Interface Name"))
	local interfaces = luci.sys and luci.sys.net and luci.sys.net.devices() or {}
	for i, v in ipairs(interfaces) do
		o:value(v, v)
	end
	o = s:option(DynamicList, "ac_allowed_container", translate("Containers allowed to be accessed"), translate("Which container(s) under bridge network can be accessed, even from interfaces that are not allowed, fill-in Container Id or Name"))
	-- allowed_container.placeholder = "container name_or_id"
	if containers_list then
		for i, v in ipairs(containers_list) do
			if	v.State == "running" and v.NetworkSettings and v.NetworkSettings.Networks and v.NetworkSettings.Networks.bridge and v.NetworkSettings.Networks.bridge.IPAddress then
				o:value(v.Id:sub(1,12), v.Names[1]:sub(2) .. " | " .. v.NetworkSettings.Networks.bridge.IPAddress)
			end
		end
	end

	o = s:option(Flag, "daemon_ea", translate("Enable"))
	o.enabled = "true"
	o.disabled = "false"
	o.rmempty = true

	o = s:option( Value, "data_root",
		translate("Docker Root Dir"))
	o.placeholder = "/opt/docker/"
	o:depends("remote_endpoint", 0)

	o = s:option(Value, "bip",
		translate("Default bridge"),
		translate("Configure the default bridge network"))
	o.placeholder = "172.17.0.1/16"
	o.datatype = "ipaddr"
	o:depends("remote_endpoint", 0)

	o = s:option(DynamicList, "registry_mirrors",
		translate("Registry Mirrors"),
		translate("It replaces the daemon registry mirrors with a new set of registry mirrors"))
	o.placeholder = translate("Example: https://hub-mirror.c.163.com")
	o:depends("remote_endpoint", 0)

	o = s:option(ListValue, "log_level",
		translate("Log Level"),
		translate('Set the logging level'))
	o:value("debug", "debug")
	o:value("info", "info")
	o:value("warn", "warn")
	o:value("error", "error")
	o:value("fatal", "fatal")
	o:depends("remote_endpoint", 0)

	o = s:option(DynamicList, "hosts",
		translate("Client connection"),
		translate('Specifies where the Docker daemon will listen for client connections'))
	o:value("unix://var/run/docker.sock", "unix://var/run/docker.sock")
	o:value("tcp://0.0.0.0:2375", "tcp://0.0.0.0:2375")
	o.rmempty = true
	o:depends("remote_endpoint", 0)

	local daemon_changes = 0
	m.on_before_save = function(self)
		local m_changes = m.uci:changes("dockerd")
		if not m_changes or not m_changes.dockerd or not m_changes.dockerd.dockerman then return end

		if m_changes.dockerd.dockerman.daemon_hosts then
			m.uci:set("dockerd", "globals", "hosts", m_changes.dockerd.dockerman.daemon_hosts)
			daemon_changes = 1
		end
		if m_changes.dockerd.dockerman.daemon_registry_mirrors then
			m.uci:set("dockerd", "globals", "registry_mirrors", m_changes.dockerd.dockerman.daemon_registry_mirrors)
			daemon_changes = 1
		end
		if m_changes.dockerd.dockerman.daemon_data_root then
			m.uci:set("dockerd", "globals", "data_root", m_changes.dockerd.dockerman.daemon_data_root)
			daemon_changes = 1
		end
		if m_changes.dockerd.dockerman.daemon_log_level then
			luci.model.uci.cursor():set("dockerd", "globals", "log_level", m_changes.dockerd.dockerman.daemon_log_level)
			daemon_changes = 1
		end
		if m_changes.dockerd.dockerman.daemon_ea then
			if m_changes.dockerd.dockerman.daemon_ea == "false" then
				daemon_changes = -1
			elseif daemon_changes == 0 then
				daemon_changes = 1
			end
		end
	end

	m.on_after_commit = function(self)
		if daemon_changes == 1 then
			luci.util.exec("/etc/init.d/dockerd enable")
			luci.util.exec("/etc/init.d/dockerd restart")
		elseif daemon_changes == -1 then
			luci.util.exec("/etc/init.d/dockerd stop")
			luci.util.exec("/etc/init.d/dockerd disable")
		end
		luci.util.exec("/etc/init.d/dockerman start")
	end
end

return m
