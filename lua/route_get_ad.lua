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

local function slot_key(slot)
	return "isu4:slot:" .. slot
end

local function ad_key(slot, id)
	return "isu4:ad:" .. slot .. "-" ..  id
end

local function next_ad_id()
	return "isu4:ad-next"
end

local function get_ad(slot, id)
	key = ad_key(slot, id)
	local res_all, err =  red:hgetall(key)	
	local res = {}
        for i, ver in ipairs(res_all) do
		if i % 2 == 1 then
			res[ver] = res_all[i+1]
		end
        end


	if err or not res or res == nil or res["id"] == nil then
		return nil
	end

	res['impressions'] = tonumber(res['impressions'])
	local ad_id = tonumber(res['id'])	
	local hosted_by = tonumber(res['hosted_by'])
	
	local host = "http://52.193.220.196:8888/slots/"
	if hosted_by == 1 then
		host = "http://52.198.140.176:8888/slots/"
	end
	if hosted_by == 3 then
		host = "http://52.192.211.180:8888/slots/"
	end
	
	res['asset'] = host  .. slot .. "/ads/" .. id .. "/asset"
	res['counter'] = host .. slot .. "/ads/" .. id .. "/counter"
	res['redirect'] = host .. slot .. "/ads/" .. id .. "/redirect"

	return res
end



local function next_ad(slot)
	key = slot_key(slot)

	local id_key, err = red:rpoplpush(key, key)
	if err or not id_key or id_key == ngx.null then
		return nil
	end

	local ad = get_ad(slot, id_key)
	if ad then
		return ad
	end
	redis:lrem(key, 0, id_key)
	return next_ad(slot)
end

res = next_ad(slot, id)
if not res or res == ngx.null then
  ngx.status = ngx.HTTP_NOT_FOUND
  ngx.header.content_type = "application/json; charset=utf-8";
  ngx.say(cjson.encode({error = "not_found"}))
  return
end

-- local url = "http://52.193.220.196:8888/slots/" .. slot .. "/ads/" .. res["id"]
-- ngx.redirect(url)
ngx.say(cjson.encode(res))

return
