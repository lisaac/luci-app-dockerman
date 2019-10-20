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

function get_images()
  local images = dk.images:list().body
  local data = {}
  for i, v in ipairs(images) do
    local index = v.Created .. v.Id
    data[index]={}
    data[index]["_selected"] = 0
    data[index]["_id"] = v.Id:sub(8,20)
    data[index]["_containers"] = tostring(v.Containers)
    if v.RepoTags then
      data[index]["_tags"] = v.RepoTags[1]
    else 
      _,_, data[index]["_tags"] = v.RepoDigests[1]:find("^(.-)@.+")
      data[index]["_tags"]=data[index]["_tags"]..":none"
    end
    data[index]["_size"] = string.format("%.2f", tostring(v.Size/1024/1024)).."MB"
    data[index]["_created"] = os.date("%Y/%m/%d %H:%M:%S",v.Created)
  end
  return data
end

local image_list = get_images()
m = Map("docker", translate("Docker"))

image_table = m:section(Table, image_list, translate("Images"))

image_selecter = image_table:option(Flag, "_selected","")
image_selecter.disabled = 0
image_selecter.enabled = 1
image_selecter.default = 0

image_id = image_table:option(DummyValue, "_id", translate("ID"))
image_table:option(DummyValue, "_containers", translate("Containers"))
image_table:option(DummyValue, "_tags", translate("RepoTags"))
image_table:option(DummyValue, "_size", translate("Size"))
image_table:option(DummyValue, "_created", translate("Created"))
image_selecter.write = function(self, section, value)
  image_list[section]._selected = value
end

action = m:section(Table,{{}})
action.template="cbi/inlinetable"
btnremove = action:option(Button, "remove", translate("Remove"))
btnremove.inputstyle = "remove"
btnremove.write = function(self, section)
  local image_selected = {}
  -- 遍历table中sectionid
  local image_table_sids = image_table:cfgsections()
  for _, image_table_sid in ipairs(image_table_sids) do
    -- 得到选中项的名字
    if image_list[image_table_sid]._selected == 1 then
      image_selected[#image_selected+1] = image_id:cfgvalue(image_table_sid)
    end
  end
  if next(image_selected) ~= nil then
    for _,img in ipairs(image_selected) do
      dk.images["remove"](dk, img)
    end
    luci.http.redirect(luci.dispatcher.build_url("admin/docker/images"))
  end
end
return m