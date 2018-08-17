local _M = {}

function _M.execute(conf)
    if conf.say_hello then
        ngx.log(ngx.ERR, "========= Hello World! ========")
        ngx.header["Hello-World"] = "Hello World!!!"
    else
        ngx.log(ngx.ERR, "========= Bye World ========")
        ngx.header["Hello-World"] = "Bye World!!!"
    end
end

return _M