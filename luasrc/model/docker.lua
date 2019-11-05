require "luci.util"
local docker = require "luci.docker"
local uci = (require "luci.model.uci").cursor()

_docker = {}
_docker.new = function(option)
  local option = option or {}
  options = {
    socket_path = option.socket_path or uci.get("docker","local", "socket_path"),
    status_enabled = option.status_enabled or uci.get("docker","local", "status_enabled") == 'true' and true or false,
    status_path = option.status_path or uci.get("docker","local", "status_path"),
    debug = option.debug or uci.get("docker","local", "debug") == 'true' and true or false,
    debug_path = option.debug_path or uci.get("docker","local", "debug_path")
  }
  return docker.new(options)
end

return _docker