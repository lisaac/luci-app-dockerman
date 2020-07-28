--[[
LuCI - Lua Configuration Interface
Copyright 2019 lisaac <https://github.com/lisaac/luci-app-dockerman>
]]--

local docker = require "luci.model.docker"

module("luci.controller.dockerman",package.seeall)

function index()
	local e = entry({"admin", "docker"}, firstchild(), "Docker", 40)
	e.dependent = false
	e.acl_depends = { "luci-app-dockerman" }

	entry({"admin", "docker", "overview"},cbi("dockerman/overview"),_("Overview"),0).leaf=true

	local remote = luci.model.uci.cursor():get_bool("dockerd", "globals", "remote_endpoint")
	if remote then
		local host = luci.model.uci.cursor():get("dockerd", "globals", "remote_host")
		local port = luci.model.uci.cursor():get("dockerd", "globals", "remote_port")
		if not host or not port then
			return
		end
	else
		local socket = luci.model.uci.cursor():get("dockerd", "globals", "socket_path")
		if socket and not nixio.fs.access(socket) then
			return
		end
	end

	if (require "luci.model.docker").new():_ping().code ~= 200 then
		return
	end

	entry({"admin", "docker", "containers"}, form("dockerman/containers"), _("Containers"),1).leaf=true
	entry({"admin", "docker", "images"}, form("dockerman/images"), _("Images"),2).leaf=true
	entry({"admin", "docker", "networks"}, form("dockerman/networks"), _("Networks"),3).leaf=true
	entry({"admin", "docker", "volumes"}, form("dockerman/volumes"), _("Volumes"),4).leaf=true
	entry({"admin", "docker", "events"}, call("action_events"), _("Events"),5)

	entry({"admin", "docker", "newcontainer"}, form("dockerman/newcontainer")).leaf=true
	entry({"admin", "docker", "newnetwork"}, form("dockerman/newnetwork")).leaf=true
	entry({"admin", "docker", "container"}, form("dockerman/container")).leaf=true

	entry({"admin", "docker", "container_stats"}, call("action_get_container_stats")).leaf=true
	entry({"admin", "docker", "container_get_archive"}, call("download_archive")).leaf=true
	entry({"admin", "docker", "container_put_archive"}, call("upload_archive")).leaf=true
	entry({"admin", "docker", "images_save"}, call("save_images")).leaf=true
	entry({"admin", "docker", "images_load"}, call("load_images")).leaf=true
	entry({"admin", "docker", "images_import"}, call("import_images")).leaf=true
	entry({"admin", "docker", "images_get_tags"}, call("get_image_tags")).leaf=true
	entry({"admin", "docker", "images_tag"}, call("tag_image")).leaf=true
	entry({"admin", "docker", "images_untag"}, call("untag_image")).leaf=true
	entry({"admin", "docker", "confirm"}, call("action_confirm")).leaf=true
end

function scandir(id, directory)
  local cmd_docker = luci.util.exec("which docker"):match("^.+docker") or nil
  if not cmd_docker or cmd_docker:match("^%s+$") then return end
  local i, t, popen = 0, {}, io.popen
  local uci = (require "luci.model.uci").cursor()
  local remote = uci:get("dockerd", "dockerman", "remote_endpoint")
  local socket_path = (remote == "false" or not remote) and  uci:get("dockerd", "dockerman", "socket_path") or nil
  local host = (remote == "true") and uci:get("dockerd", "dockerman", "remote_host") or nil
  local port = (remote == "true") and uci:get("dockerd", "dockerman", "remote_port") or nil
  if remote and host and port then
    hosts = host .. ':'.. port
  elseif socket_path then
    hosts = "unix://" .. socket_path
  else
    return
  end
  local pfile = popen(cmd_docker .. ' -H "'.. hosts ..'" exec ' ..id .." ls -lh \""..directory.."\" | egrep -v '^total'")
  for fileinfo in pfile:lines() do
      i = i + 1
      t[i] = fileinfo
  end
  pfile:close()
  return t
end

function list_response(id, path, success)
  luci.http.prepare_content("application/json")
  local result
  if success then
      local rv = scandir(id, path)
      result = {
          ec = 0,
          data = rv
      }
  else
      result = {
          ec = 1
      }
  end
  luci.http.write_json(result)
end

function list_file(id)
  local path = luci.http.formvalue("path")
  list_response(id, path, true)
end

function rename_file(id)
  local filepath = luci.http.formvalue("filepath")
  local newpath = luci.http.formvalue("newpath")
  local cmd_docker = luci.util.exec("which docker"):match("^.+docker") or nil
  if not cmd_docker or cmd_docker:match("^%s+$") then return end
  local uci = (require "luci.model.uci").cursor()
  local remote = uci:get("dockerd", "dockerman", "remote_endpoint")
  local socket_path = (remote == "false" or not remote) and  uci:get("dockerd", "dockerman", "socket_path") or nil
  local host = (remote == "true") and uci:get("dockerd", "dockerman", "remote_host") or nil
  local port = (remote == "true") and uci:get("dockerd", "dockerman", "remote_port") or nil
  if remote and host and port then
    hosts = host .. ':'.. port
  elseif socket_path then
    hosts = "unix://" .. socket_path
  else
    return
  end
  local success = os.execute(cmd_docker .. ' -H "'.. hosts ..'" exec '.. id ..' mv "'..filepath..'" "'..newpath..'"')
  list_response(nixio.fs.dirname(filepath), success)
end

function remove_file(id)
  local path = luci.http.formvalue("path")
  local isdir = luci.http.formvalue("isdir")
  local cmd_docker = luci.util.exec("which docker"):match("^.+docker") or nil
  if not cmd_docker or cmd_docker:match("^%s+$") then return end 
  local uci = (require "luci.model.uci").cursor()
  local remote = uci:get("dockerd", "dockerman", "remote_endpoint")
  local socket_path = (remote == "false" or not remote) and  uci:get("dockerd", "dockerman", "socket_path") or nil
  local host = (remote == "true") and uci:get("dockerd", "dockerman", "remote_host") or nil
  local port = (remote == "true") and uci:get("dockerd", "dockerman", "remote_port") or nil
  if remote and host and port then
    hosts = host .. ':'.. port
  elseif socket_path then
    hosts = "unix://" .. socket_path
  else
    return
  end
  path = path:gsub("<>", "/")
  path = path:gsub(" ", "\ ")
  local success
  if isdir then
      success = os.execute(cmd_docker .. ' -H "'.. hosts ..'" exec '.. id ..' rm -r "'..path..'"')
  else
      success = os.remove(path)
  end
  list_response(nixio.fs.dirname(path), success)
end

function action_events()
	local logs = ""
	local query ={}

	local dk = docker.new()
	query["until"] = os.time()
	local events = dk:events({query = query})

	if events.code == 200 then
		for _, v in ipairs(events.body) do
			if v and v.Type == "container" then
				logs = (logs ~= "" and (logs .. "\n") or logs) .. "[" .. os.date("%Y-%m-%d %H:%M:%S", v.time) .."] "..v.Type.. " " .. (v.Action or "null") .. " Container ID:"..  (v.Actor.ID or "null") .. " Container Name:" .. (v.Actor.Attributes.name or "null")
			elseif v.Type == "network" then
				logs = (logs ~= "" and (logs .. "\n") or logs) .. "[" .. os.date("%Y-%m-%d %H:%M:%S", v.time) .."] "..v.Type.. " " .. v.Action .. " Container ID:"..( v.Actor.Attributes.container or "null" ) .. " Network Name:" .. (v.Actor.Attributes.name or "null") .. " Network type:".. v.Actor.Attributes.type or ""
			elseif v.Type == "image" then
				logs = (logs ~= "" and (logs .. "\n") or logs) .. "[" .. os.date("%Y-%m-%d %H:%M:%S", v.time) .."] "..v.Type.. " " .. v.Action .. " Image:".. (v.Actor.ID or "null").. " Image Name:" .. (v.Actor.Attributes.name or "null")
			end
		end
	end

	luci.template.render("dockerman/logs", {self={syslog = logs, title="Events"}})
end

local calculate_cpu_percent = function(d)
	if type(d) ~= "table" then
		return
	end

	local cpu_count = tonumber(d["cpu_stats"]["online_cpus"])
	local cpu_percent = 0.0
	local cpu_delta = tonumber(d["cpu_stats"]["cpu_usage"]["total_usage"]) - tonumber(d["precpu_stats"]["cpu_usage"]["total_usage"])
	local system_delta = tonumber(d["cpu_stats"]["system_cpu_usage"]) - tonumber(d["precpu_stats"]["system_cpu_usage"])
	if system_delta > 0.0 then
		cpu_percent = string.format("%.2f", cpu_delta / system_delta * 100.0 * cpu_count)
	end

	return cpu_percent
end

local get_memory = function(d)
	if type(d) ~= "table" then
		return
	end

	-- local limit = string.format("%.2f", tonumber(d["memory_stats"]["limit"]) / 1024 / 1024)
	-- local usage = string.format("%.2f", (tonumber(d["memory_stats"]["usage"]) - tonumber(d["memory_stats"]["stats"]["total_cache"])) / 1024 / 1024)
	-- return usage .. "MB / " .. limit.. "MB" 
	-- luci.util.perror(luci.jsonc.stringify(d))
	local limit =tonumber(d["memory_stats"]["limit"])
	local usage = tonumber(d["memory_stats"]["usage"]) - tonumber(d["memory_stats"]["stats"]["total_cache"])

	return usage, limit
end

local get_rx_tx = function(d)
	if type(d) ~="table" then
		return
	end

	local data = {}
	if type(d["networks"]) == "table" then
		for e, v in pairs(d["networks"]) do
			data[e] = {
				bw_tx = tonumber(v.tx_bytes),
				bw_rx = tonumber(v.rx_bytes)
			}
		end
	end

	return data
end

function action_get_container_stats(container_id)
	if container_id then
		local dk = docker.new()
		local response = dk.containers:inspect({id = container_id})
		if response.code == 200 and response.body.State.Running then
			response = dk.containers:stats({id = container_id, query = {stream = false}})
			if response.code == 200 then
				local container_stats = response.body
				local cpu_percent = calculate_cpu_percent(container_stats)
				local mem_useage, mem_limit = get_memory(container_stats)
				local bw_rxtx = get_rx_tx(container_stats)
				luci.http.status(response.code, response.body.message)
				luci.http.prepare_content("application/json")
				luci.http.write_json({
					cpu_percent = cpu_percent,
					memory = {
						mem_useage = mem_useage,
						mem_limit = mem_limit
					},
					bw_rxtx = bw_rxtx
				})
			else
				luci.http.status(response.code, response.body.message)
				luci.http.prepare_content("text/plain")
				luci.http.write(response.body.message)
			end
		else
			if response.code == 200 then
				luci.http.status(500, "container "..container_id.." not running")
				luci.http.prepare_content("text/plain")
				luci.http.write("Container "..container_id.." not running")
			else
				luci.http.status(response.code, response.body.message)
				luci.http.prepare_content("text/plain")
				luci.http.write(response.body.message)
			end
		end
	else
		luci.http.status(404, "No container name or id")
		luci.http.prepare_content("text/plain")
		luci.http.write("No container name or id")
	end
end

function action_confirm()
	local data = docker:read_status()
	if data then
		data = data:gsub("\n","<br>"):gsub(" ","&nbsp;")
		code = 202
		msg = data
	else
		code = 200
		msg = "finish"
		data = "finish"
	end

	luci.http.status(code, msg)
	luci.http.prepare_content("application/json")
	luci.http.write_json({info = data})
end

function export_container(id)
  local dk = docker.new()
  local first

  local cb = function(res, chunk)
    if res.code == 200 then
      if not first then
        first = true
        luci.http.header('Content-Disposition', 'inline; filename="archive.tar"')
        luci.http.header('Content-Type', 'application\/x-tar')
      end
      luci.ltn12.pump.all(chunk, luci.http.write)
    else
      if not first then
        first = true
        luci.http.prepare_content("text/plain")
      end
      luci.ltn12.pump.all(chunk, luci.http.write)
    end
  end

  local res = dk.containers:export({id = id}, cb)
end

function download_archive()
	local id = luci.http.formvalue("id")
	local path = luci.http.formvalue("path")
	local filename = luci.http.formvalue("filename") or "archive"

	local dk = docker.new()
	local first

	local cb = function(res, chunk)
		if res.code == 200 then
			if not first then
				first = true
				luci.http.header('Content-Disposition', 'inline; filename="'.. filename .. '.tar"')
				luci.http.header('Content-Type', 'application\/x-tar')
			end
			luci.ltn12.pump.all(chunk, luci.http.write)
		else
			if not first then
				first = true
				luci.http.prepare_content("text/plain")
			end
			luci.ltn12.pump.all(chunk, luci.http.write)
		end
	end

	local res = dk.containers:get_archive({id = id, query = {path = path}}, cb)
end

function upload_archive(container_id)
	local path = luci.http.formvalue("upload-path")
	local dk = docker.new()
	local ltn12 = require "luci.ltn12"

	local rec_send = function(sinkout)
		luci.http.setfilehandler(function (meta, chunk, eof)
			if chunk then
				ltn12.pump.step(ltn12.source.string(chunk), sinkout)
			end
		end)
	end

	local res = dk.containers:put_archive({
		id = container_id,
		query = {
			path = path
		},
		body = rec_send
	})

	local msg = res and res.body and res.body.message or nil
	luci.http.status(res.code, msg)
	luci.http.prepare_content("application/json")
	luci.http.write_json({message = msg})
end

function save_images(container_id)
	local names = luci.http.formvalue("names")
	local dk = docker.new()
	local first

	local cb = function(res, chunk)
		if res.code == 200 then
			if not first then
				first = true
				luci.http.status(res.code, res.message)
				luci.http.header('Content-Disposition', 'inline; filename="images.tar"')
				luci.http.header('Content-Type', 'application\/x-tar')
			end
			luci.ltn12.pump.all(chunk, luci.http.write)
		else
			if not first then
				first = true
				luci.http.prepare_content("text/plain")
			end
			luci.ltn12.pump.all(chunk, luci.http.write)
		end
	end

	docker:write_status("Images: saving" .. " " .. container_id .. "...")
	local res = dk.images:get({
		id = container_id,
		query = {
			names = names
		}
	}, cb)
	docker:clear_status()

	local msg = res and res.body and res.body.message or nil
	luci.http.status(res.code, msg)
	luci.http.prepare_content("application/json")
	luci.http.write_json({message = msg})
end

function load_images()
	local path = luci.http.formvalue("upload-path")
	local dk = docker.new()
	local ltn12 = require "luci.ltn12"

	local rec_send = function(sinkout)
		luci.http.setfilehandler(function (meta, chunk, eof)
			if chunk then
				ltn12.pump.step(ltn12.source.string(chunk), sinkout)
			end
		end)
	end

	docker:write_status("Images: loading...")
	local res = dk.images:load({body = rec_send})
	local msg = res and res.body and ( res.body.message or res.body.stream or res.body.error ) or nil
	if res.code == 200 and msg and msg:match("Loaded image ID") then
		docker:clear_status()
		luci.http.status(res.code, msg)
	else
		docker:append_status("code:" .. res.code.." ".. msg)
		luci.http.status(300, msg)
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({message = msg})
end

function import_images()
	local src = luci.http.formvalue("src")
	local itag = luci.http.formvalue("tag")
	local dk = docker.new()
	local ltn12 = require "luci.ltn12"

	local rec_send = function(sinkout)
		luci.http.setfilehandler(function (meta, chunk, eof)
			if chunk then
				ltn12.pump.step(ltn12.source.string(chunk), sinkout)
			end
		end)
	end

	docker:write_status("Images: importing".. " ".. itag .."...\n")
	local repo = itag and itag:match("^([^:]+)")
	local tag = itag and itag:match("^[^:]-:([^:]+)")
	local res = dk.images:create({
		query = {
			fromSrc = src or "-",
			repo = repo or nil,
			tag = tag or nil
		},
		body = not src and rec_send or nil
	}, docker.import_image_show_status_cb)

	local msg = res and res.body and ( res.body.message )or nil
	if not msg and #res.body == 0 then
		msg = res.body.status or res.body.error
	elseif not msg and #res.body >= 1 then
		msg = res.body[#res.body].status or res.body[#res.body].error
	end

	if res.code == 200 and msg and msg:match("sha256:") then
		docker:clear_status()
	else
		docker:append_status("code:" .. res.code.." ".. msg)
	end

	luci.http.status(res.code, msg)
	luci.http.prepare_content("application/json")
	luci.http.write_json({message = msg})
end

function get_image_tags(image_id)
	if not image_id then
		luci.http.status(400, "no image id")
		luci.http.prepare_content("application/json")
		luci.http.write_json({message = "no image id"})
		return
	end

	local dk = docker.new()
	local res = dk.images:inspect({
		id = image_id
	})
	local msg = res and res.body and res.body.message or nil
	luci.http.status(res.code, msg)
	luci.http.prepare_content("application/json")

	if res.code == 200 then
		local tags = res.body.RepoTags
		luci.http.write_json({tags = tags})
	else
		local msg = res and res.body and res.body.message or nil
		luci.http.write_json({message = msg})
	end
end

function tag_image(image_id)
	local src = luci.http.formvalue("tag")
	local image_id = image_id or luci.http.formvalue("id")

	if type(src) ~= "string" or not image_id then
		luci.http.status(400, "no image id or tag")
		luci.http.prepare_content("application/json")
		luci.http.write_json({message = "no image id or tag"})
		return
	end

	local repo = src:match("^([^:]+)")
	local tag = src:match("^[^:]-:([^:]+)")
	local dk = docker.new()
	local res = dk.images:tag({
		id = image_id,
		query={
			repo=repo,
			tag=tag
		}
	})
	local msg = res and res.body and res.body.message or nil
	luci.http.status(res.code, msg)
	luci.http.prepare_content("application/json")

	if res.code == 201 then
		local tags = res.body.RepoTags
		luci.http.write_json({tags = tags})
	else
		local msg = res and res.body and res.body.message or nil
		luci.http.write_json({message = msg})
	end
end

function untag_image(tag)
	local tag = tag or luci.http.formvalue("tag")

	if not tag then
		luci.http.status(400, "no tag name")
		luci.http.prepare_content("application/json")
		luci.http.write_json({message = "no tag name"})
		return
	end

	local dk = docker.new()
	local res = dk.images:inspect({name = tag})

	if res.code == 200 then
		local tags = res.body.RepoTags
		if #tags > 1 then
			local r = dk.images:remove({name = tag})
			local msg = r and r.body and r.body.message or nil
			luci.http.status(r.code, msg)
			luci.http.prepare_content("application/json")
			luci.http.write_json({message = msg})
		else
			luci.http.status(500, "Cannot remove the last tag")
			luci.http.prepare_content("application/json")
			luci.http.write_json({message = "Cannot remove the last tag"})
		end
	else
		local msg = res and res.body and res.body.message or nil
		luci.http.status(res.code, msg)
		luci.http.prepare_content("application/json")
		luci.http.write_json({message = msg})
	end
end
