
local docker = require "luci.docker"

module("luci.controller.docker",package.seeall)


function index()
local e
-- entry({"docker"},cbi("docker/overview"),_("Docker"))
entry({"admin", "docker"}, firstchild(), "Docker", 40).dependent = false
entry({"admin","docker","containers"},cbi("docker/containers", {hideapplybtn=true, hidesavebtn=true, hideresetbtn=true}),_("Containers"),1).leaf=true
entry({"admin","docker","networks"},cbi("docker/networks", {hideapplybtn=true, hidesavebtn=true, hideresetbtn=true}),_("Networks"),3).leaf=true
entry({"admin","docker","images"},cbi("docker/images", {hideapplybtn=true, hidesavebtn=true, hideresetbtn=true}),_("Images"),2).leaf=true
entry({"admin","docker","logs"},call("action_logs"),_("Logs"),4)
entry({"admin","docker","newcontainer"},cbi("docker/newcontainer")).leaf=true
entry({"admin","docker","container"},cbi("docker/container")).leaf=true
end


function action_logs()
  local logs = ""
  local dk = docker.new()
  local query ={}
  query["until"] = os.time()
	local events = dk:events(nil, query)
  for _, v in ipairs(events.body) do
    if v.Type == "container" then
      logs = (logs ~= "" and (logs .. "\n") or logs) .. "[" .. os.date("%Y-%m-%d %H:%M:%S", v.time) .."] "..v.Type.. " " .. v.Action .. " Container ID:"..  v.Actor.ID .. " Container Name:" .. v.Actor.Attributes.name
    elseif v.Type == "network" then
      logs = (logs ~= "" and (logs .. "\n") or logs) .. "[" .. os.date("%Y-%m-%d %H:%M:%S", v.time) .."] "..v.Type.. " " .. v.Action .. " Container ID:".. v.Actor.Attributes.container.. " Network Name:" .. v.Actor.Attributes.name .. " Network type:".. v.Actor.Attributes.type
    elseif v.Type == "image" then
      logs = (logs ~= "" and (logs .. "\n") or logs) .. "[" .. os.date("%Y-%m-%d %H:%M:%S", v.time) .."] "..v.Type.. " " .. v.Action .. " Image:".. v.Actor.ID.. " Image Name:" .. v.Actor.Attributes.name
    end
  end
  luci.template.render("docker/logs", {syslog=logs})
end