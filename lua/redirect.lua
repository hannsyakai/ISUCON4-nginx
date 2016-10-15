local cjson = require "cjson"
local mysql = require "resty.mysql"
local redis = require "resty.redis"

local db, err = mysql:new()
if not db then
  ngx.log(ngx.ERR, "failed to instantiate mysql: ", err)
  return
end

local ok, err, errno, sqlstate = db:connect {
  host = "52.192.211.180",
  database = "isucon",
  user = "root",
  password = "weitarou",
  charset=utf8mb4
}

if not ok then
  ngx.log(ngx.ERR, "failed to connect: ", err, ": ", errno, " ", sqlstate);
  return
end

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

res, err = red:hmget(key, "id", "advertiser", "destination")
if not res or res == ngx.null then
  ngx.status = ngx.HTTP_NOT_FOUND
  ngx.header.content_type = "application/json; charset=utf-8";
  ngx.say(cjson.encode({error = "not_found"}))
  return
end

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end


local ad_id = res[1];
local ad_advertiser = res[2];
local ad_destination = res[3];
local c = split(ngx.var.c, "/");
local c_front = c[1];
local c_back = c[2];

local sex = "-1";
if c_front then
  sex = c_front;
end

local age = "-1";
if c_back then
  age = c_back;
end

local ua = ngx.req.get_headers()["User-Agent"];

local sql = "INSERT INTO logs (ad_id, advertiser, sex, age, agent) VALUES (" ..  ngx.quote_sql_str(ad_id) .. "," ..  ngx.quote_sql_str(ad_advertiser) .. "," ..  ngx.quote_sql_str(sex) .. "," ..  ngx.quote_sql_str(age) .. "," ..  ngx.quote_sql_str(ua) .. ")";

local res, err, errno, sqlstate = db:query(sql);

if err then
  ngx.log(ngx.ERR, "failed to insert to mysql: ", err)
end

return ngx.redirect(ad_destination);

