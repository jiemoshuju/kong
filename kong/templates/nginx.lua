return [[
> if nginx_user then
user ${{NGINX_USER}};
> end
worker_processes ${{NGINX_WORKER_PROCESSES}};
daemon ${{NGINX_DAEMON}};

pid pids/nginx.pid;
error_log ${{PROXY_ERROR_LOG}} ${{LOG_LEVEL}};

> if nginx_optimizations then
worker_rlimit_nofile ${{WORKER_RLIMIT}};
> end

events {
> if nginx_optimizations then
    worker_connections ${{WORKER_CONNECTIONS}};
    multi_accept on;
> end
}

http {
    log_format  main  '$remote_addr $time_iso8601 $msec $request_time $request_length '
        '$connection $connection_requests $uri "$request" '
        '$status $body_bytes_sent "$http_referer" '
        '"$http_X_AK_KEY" "$http_X_AK_TS" "$http_X_AK_PIN"'
        '"$http_user_agent" "$http_x_forwarded_for" "$http_host" "$sent_http_X_AK_ERROR_CODE" "$sent_http_X_AK_ERROR_MSG" "$upstream_addr" "$upstream_response_time"';

    access_log  logs/access.log  main;
    include 'nginx-kong.conf';
    include 'nginx-websites.conf';
}
]]
