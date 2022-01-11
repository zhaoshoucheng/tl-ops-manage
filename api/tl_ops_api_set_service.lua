-- tl_ops_api 
-- en : set balance service node config list
-- zn : 更新负载服务节点配置列表
-- @author iamtsm
-- @email 1905333456@qq.com


local cjson = require("cjson");
local snowflake = require("lib.snowflake");
local cache = require("cache.tl_ops_cache"):new("tl-ops-service");
local tl_ops_constant_balance = require("constant.tl_ops_constant_balance");
local tl_ops_rt = require("constant.tl_ops_constant_comm").tl_ops_rt;
local tl_ops_utils_func = require("utils.tl_ops_utils_func");
local tl_ops_constant_health = require("constant.tl_ops_constant_health");
local tl_ops_health_check_version = require("health.tl_ops_health_check_version")


local tl_ops_service_rule,err = tl_ops_utils_func:get_req_post_args_by_name(tl_ops_constant_balance.service.rule.cache_key, 1);
if not tl_ops_service_rule or tl_ops_service_rule == nil then
    tl_ops_utils_func:set_ngx_req_return_ok(tl_ops_rt.args_error ,"args err1", err);
    return;
end

local tl_ops_service_list,err = tl_ops_utils_func:get_req_post_args_by_name(tl_ops_constant_balance.service.list.cache_key, 1);
if not tl_ops_service_list or tl_ops_service_list == nil then
    tl_ops_utils_func:set_ngx_req_return_ok(tl_ops_rt.args_error ,"args err2", err);
    return;
end

---- 更新生成id
for key,_ in pairs(tl_ops_service_list) do
    for _, service in ipairs(tl_ops_service_list[key]) do
        service.id = snowflake.generate_id( 100 )
        service.updatetime = ngx.localtime()
    end
end


local cache_list, _ = cache:set(tl_ops_constant_balance.service.list.cache_key, cjson.encode(tl_ops_service_list));
if not cache_list then
    tl_ops_utils_func:set_ngx_req_return_ok(tl_ops_rt.error, "set list err", _)
    return;
end


local cache_rule, _ = cache:set(tl_ops_constant_balance.service.rule.cache_key, tl_ops_service_rule);
if not cache_rule then
    tl_ops_utils_func:set_ngx_req_return_ok(tl_ops_rt.error, "set rule err ", _)
    return;
end


local is_add_service , _ = tl_ops_utils_func:get_req_post_args_by_name(tl_ops_constant_health.cache_key.service_options_version, 1);
if is_add_service and is_add_service == true then
    ---- 对service_options_version更新，通知timer检查是否有新增service
    tl_ops_health_check_version.incr_service_option_version();
end

---- 对service version更新，通知worker更新所有conf
for service_name , _ in pairs(tl_ops_service_list) do
    tl_ops_health_check_version.incr_service_version(service_name);
end

local res_data = {}
res_data[tl_ops_constant_balance.service.rule.cache_key] = tl_ops_service_rule
res_data[tl_ops_constant_balance.service.list.cache_key] = tl_ops_service_list


tl_ops_utils_func:set_ngx_req_return_ok(tl_ops_rt.ok, "ok", res_data)