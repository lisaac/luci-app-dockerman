module("luci.controller.docker",package.seeall)
function index()
local e
-- entry({"docker"},cbi("docker/overview"),_("Docker"))
entry({"admin", "docker"}, firstchild(), "Docker", 40).dependent = false
entry({"admin","docker","containers"},cbi("docker/containers", {hideapplybtn=true, hidesavebtn=true, hideresetbtn=true}),_("Containers"),1).leaf=true
entry({"admin","docker","networks"},cbi("docker/networks", {hideapplybtn=true, hidesavebtn=true, hideresetbtn=true}),_("Networks"),3).leaf=true
entry({"admin","docker","images"},cbi("docker/images", {hideapplybtn=true, hidesavebtn=true, hideresetbtn=true}),_("Images"),2).leaf=true
entry({"admin","docker","logs"},cbi("docker/logs", {hideapplybtn=true, hidesavebtn=true, hideresetbtn=true}),_("Logs"),4).leaf=true
entry({"admin","docker","newcontainer"},cbi("docker/newcontainer")).leaf=true
entry({"admin","docker","container"},cbi("docker/container")).leaf=true
end
