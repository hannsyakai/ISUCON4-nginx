local cjson = require "cjson"
local redis = require "resty.redis"
local red = redis:new()

local redis_host = "52.193.220.196"
local redis_port = 6379
local ok, err = red:connect(redis_host, redis_port)
if not ok then
  ngx.say("failed to connect: ", err)
end

local slot = ngx.var.slot;
local id = ngx.var.id;
local key = "isu4:ad:" .. slot .. "-" .. id

res, err = red:exists(key)
if not res or res == ngx.null or res == 0 then
  ngx.status = ngx.HTTP_NOT_FOUND
  ngx.header.content_type = "application/json; charset=utf-8";
  ngx.say(cjson.encode({error = "not_found"}))
  return
end

res, err = red:hincrby(key, "impressions", 1)

ngx.status = 204

return
