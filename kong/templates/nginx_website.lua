local pl_stringx = require "pl.stringx"
local pl_path = require "pl.path"
local fmt = string.format

local _M = {}

local website_template = [[
server {
    listen %s;
    server_name %s;

    #resolver dns conf
    %s

#ssl block conf
%s

    #root config
    %s

    gzip on;
    gzip_min_length 1k;
    gzip_buffers 4 16k;
    gzip_comp_level 5;
    gzip_types text/plain application/x-javascript application/javascript text/css application/xml text/javascript application/x-httpd-php;
    gzip_vary on;
    gzip_disable "MSIE [1-6]\.";

#location block
%s

}

]]


local staticResourceBlock = [[

location ~* .(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1d;
}

location / {
    try_files $uri $uri/ @router;
    index index.html;
}

location @router {
    rewrite ^.*$ /index.html last;
}

]]

local sslBlock = [[
    ssl_certificate      ssl/%s.crt;
    ssl_certificate_key  ssl/%s.key;

    ssl_session_cache    shared:SSL:10m;
    ssl_session_timeout  10m;

    ssl_protocols        TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers          HIGH:!aNULL:!MD5:!kEDH;
    ssl_prefer_server_ciphers   on;
    lua_check_client_abort      on;
]]

local locationBlock = [[

location %s {
    proxy_pass http://localhost:8000;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Connection "keep-alive";
    proxy_set_header Host "%s";
    proxy_http_version 1.1;
    proxy_connect_timeout 5;
    proxy_send_timeout 30;
    proxy_read_timeout 30;
}

]]

local function get_domain(serverName)
  local mt = pl_stringx.split(serverName,' ')
  local serverDomain = pl_stringx.split(mt[1],'.')
  local domain = ''
  if #serverDomain >= 1 and tonumber(serverDomain[#serverDomain-1]) == nil 
    and tonumber(serverDomain[#serverDomain]) == nil then
      domain = serverDomain[#serverDomain-1] .. "." .. serverDomain[#serverDomain]
  else
      domain = mt[1]
  end
  return domain
end

local function getWebsiteConf(webConf,sslprefix)
  if type(webConf) ~= "table" then
      return nil,'website conf miss'
  end

  local data = {
    listen = webConf.listen or 80,
    server_name = webConf.server_name,
    resolver = '',
    ssl = '',
    root = '',
    locations = ''
  }

  if webConf['resolver'] and webConf['resolver'] ~= '' then
    data.resolver = "resolver    " .. webConf['resolver'] .. " valid=3600s;"
  end

  local domain = get_domain(webConf['server_name'])
  if webConf['listen'] == 443 then
    if not pl_path.exists(pl_path.join(sslprefix, 'ssl', domain .. ".crt"))
      or not pl_path.exists(pl_path.join(sslprefix, 'ssl', domain .. ".key")) then
      return nil, domain .. ' miss ssl_certificate keypairs'
    end
    data.ssl = fmt(sslBlock, domain, domain)
  end

  if webConf['locations'] and #webConf['locations'] > 0 then
    for _,locpath in ipairs(webConf['locations']) do
      data.locations = data.locations .. fmt(locationBlock,locpath,webConf['server_name'])
    end
  end

  if webConf['root'] and webConf['root'] ~= '' then
    data.root = "root    " .. webConf['root'] .. ";"
    data.locations = data.locations .. staticResourceBlock
  end

  return fmt(website_template,
    data['listen'],data['server_name'],
    data['resolver'],data['ssl'],data['root'],data['locations'])
end


return {
  website_template = website_template,
  get_domain = get_domain,
  getWebsiteConf = getWebsiteConf
}