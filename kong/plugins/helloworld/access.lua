local _M = {}

function _M.execute(conf)
    if conf.say_hello then
        ngx.log(ngx.ERR, "========= Hello World! ========")
        ngx.header["Hello-World"] = "Hello World!!!"
    else
        ngx.log(ngx.ERR, "========= Bye World ========")
        ngx.header["Hello-World"] = "Bye World!!!"
    end
    ngx.header.Content_Type = "text/plain"
    ngx.log(ngx.ERR, ngx.req.get_headers()["Host"])
    ngx.print(conf.dbname .. ngx.req.get_headers()["Host"] .. " nsns2")
    ngx.exit(200)
end

return _M