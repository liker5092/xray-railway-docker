FROM alpine:latest

# 1. 安装基础工具：curl(下载), unzip(解压), lighttpd, procps(pgrep), ca-certificates(SSL支持)
RUN apk add --no-cache lighttpd curl procps ca-certificates unzip

# 2. 自动下载并安装 Xray 二进制文件
# 自动识别架构 (amd64 或 arm64) 并下载最新版
RUN set -ex && \
    mkdir -p /usr/bin/xray /etc/xray /var/www/localhost/htdocs && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then PLAT="64"; else PLAT="arm64-v8a"; fi && \
    curl -L -H "Cache-Control: no-cache" -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${PLAT}.zip" && \
    unzip /tmp/xray.zip -d /usr/bin/xray && \
    chmod +x /usr/bin/xray/xray && \
    rm /tmp/xray.zip

# 3. 使用 echo 写入 lighttpd 配置文件 (监听 60080)
RUN echo 'server.modules = ( "mod_access", "mod_accesslog" )' > /etc/lighttpd/lighttpd.conf && \
    echo 'server.port = 60080' >> /etc/lighttpd/lighttpd.conf && \
    echo 'server.document-root = "/var/www/localhost/htdocs"' >> /etc/lighttpd/lighttpd.conf && \
    echo 'server.indexfiles = ( "index.html" )' >> /etc/lighttpd/lighttpd.conf && \
    echo 'mimetype.assign = ( ".html" => "text/html", ".txt" => "text/plain", ".jpg" => "image/jpeg", ".png" => "image/png" )' >> /etc/lighttpd/lighttpd.conf

# 4. 使用 echo 写入 Xray 配置文件 (43201 端口, VLESS 协议)
# 注意：这里使用了单引号包裹内容，确保 JSON 内部的双引号不被转义干扰
RUN echo '{' > /etc/xray/config.json && \
    echo '  "log": { "loglevel": "warning", "maskAddress": "" },' >> /etc/xray/config.json && \
    echo '  "routing": { "domainStrategy": "AsIs", "rules": [ { "type": "field", "inboundTag": ["api"], "outboundTag": "api" } ] },' >> /etc/xray/config.json && \
    echo '  "inbounds": [' >> /etc/xray/config.json && \
    echo '    { "listen": "127.0.0.1", "port": 62789, "protocol": "tunnel", "settings": { "address": "127.0.0.1" }, "tag": "api" },' >> /etc/xray/config.json && \
    echo '    { "listen": "0.0.0.0", "port": 43201, "protocol": "vless", "settings": { "clients": [ { "email": "toj867ch", "id": "16aec472-c085-44ee-a98e-e2ec4c63a9ae" } ], "decryption": "none" },' >> /etc/xray/config.json && \
    echo '      "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "host": "www.bing.com", "path": "/" } }, "tag": "inbound-43201" }' >> /etc/xray/config.json && \
    echo '  ],' >> /etc/xray/config.json && \
    echo '  "outbounds": [ { "tag": "direct", "protocol": "freedom", "settings": { "domainStrategy": "AsIs" } } ],' >> /etc/xray/config.json && \
    echo '  "api": { "tag": "api", "services": ["HandlerService", "LoggerService", "StatsService"] },' >> /etc/xray/config.json && \
    echo '  "metrics": { "tag": "metrics_out", "listen": "127.0.0.1:11111" }' >> /etc/xray/config.json && \
    echo '}' >> /etc/xray/config.json

# 5. 优化后的 entrypoint.sh 脚本
RUN echo '#!/bin/sh' > /entrypoint.sh && \
    echo '# 立即启动服务' >> /entrypoint.sh && \
    echo '/usr/bin/xray/xray run -c /etc/xray/config.json &' >> /entrypoint.sh && \
    echo 'lighttpd -D -f /etc/lighttpd/lighttpd.conf &' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# 每20秒检查一次进程' >> /entrypoint.sh && \
    echo 'while true; do' >> /entrypoint.sh && \
    echo '  sleep 20' >> /entrypoint.sh && \
    echo '  pgrep xray > /dev/null || (/usr/bin/xray/xray run -c /etc/xray/config.json &)' >> /entrypoint.sh && \
    echo '  pgrep lighttpd > /dev/null || (lighttpd -D -f /etc/lighttpd/lighttpd.conf &)' >> /entrypoint.sh && \
    echo 'done' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 6. 生成测试主页
RUN echo "Railway Node is Online" > /var/www/localhost/htdocs/index.html

# 暴露端口
EXPOSE 43201 60080

# 启动
CMD ["/bin/sh", "/entrypoint.sh"]
