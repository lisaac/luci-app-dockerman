-- Copyright 2021 Florian Eckert <fe@dev.tdt.de>
-- Licensed to the public under the Apache License 2.0.

local m, s, o

m = Map("dockerd",
	translate("Docker - Configuration"),
	translate("DockerMan is a simple docker manager client for LuCI"))

s = m:section(NamedSection, "globals", "section", translate("Global settings"))

o = s:option(Flag, "remote_endpoint",
	translate("Remote Endpoint"),
	translate("Connect to remote endpoint"))
o.rmempty = false

-- local status_path = section_dockerman:taboption("dockerman", Value, "status_path", translate("Action Status Tempfile Path"), translate("Where you want to save the docker status file"))
-- local debug = section_dockerman:taboption("dockerman", Flag, "debug", translate("Enable Debug"), translate("For debug, It shows all docker API actions of luci-app-dockerman in Debug Tempfile Path"))
-- debug.enabled="true"
-- debug.disabled="false"
-- local debug_path = section_dockerman:taboption("dockerman", Value, "debug_path", translate("Debug Tempfile Path"), translate("Where you want to save the debug tempfile"))

o = s:option(Value, "remote_host",
	translate("Remote Host"),
	translate("Host or IP Address for the connection to a remote docker instance"))
o.datatype = "host"
o.rmempty = false
o.optional = false
o.placeholder = "10.1.1.2"
o:depends("remote_endpoint", 1)

o = s:option(Value, "remote_port",
	translate("Remote Port"))
o.placeholder = "2375"
o.datatype = "port"
o.rmempty = false
o.optional = false
o:depends("remote_endpoint", 1)

if nixio.fs.access("/usr/bin/dockerd") then
	o = s:option(Value, "data_root",
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
	o:value("debug", translate("Debug"))
	o:value("", translate("Info")) -- This is the default debug level from the deamon is optin is not set
	o:value("warn", translate("Warning"))
	o:value("error", translate("Error"))
	o:value("fatal", translate("Fatal"))
	o.rmempty = true
	o:depends("remote_endpoint", 0)

	o = s:option(DynamicList, "hosts",
		translate("Client connection"),
		translate('Specifies where the Docker daemon will listen for client connections (default: unix:///var/run/docker.sock)'))
	o.placeholder = translate("Example: tcp://0.0.0.0:2375")
	o.rmempty = true
	
	local daemon_changes = 0
	m.on_before_save = function(self)
		local m_changes = m.uci:changes("dockerd")
		if not m_changes or not m_changes.dockerd then
			return
		end

		if m_changes.dockerd.globals.hosts then
			daemon_changes = 1
		end
		if m_changes.dockerd.globals.registry_mirrors then
			daemon_changes = 1
		end
		if m_changes.dockerd.globals.data_root then
			daemon_changes = 1
		end
		if m_changes.dockerd.globals.log_level then
			daemon_changes = 1
		end
		if m_changes.dockerd.globals.daemon_ea then
			if m_changes.dockerd.globals.daemon_ea == "false" then
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
		luci.util.exec("/etc/init.d/dockerd start")
	end
	o:depends("remote_endpoint", 0)
end

return m
