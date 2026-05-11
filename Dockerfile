FROM alpine:latest

# 设置环境变量，方便后期修改 UUID
ENV UUID=e8a9d1b2-1234-4567-89ab-cdef01284567

# 1. 安装必要依赖
RUN apk add --no-cache supervisor ca-certificates curl

# 2. 下载并安装 Xray
RUN set -ex && \
    mkdir -p /usr/bin/xray /etc/xray && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then PLATFORM="64"; \
    elif [ "$ARCH" = "aarch64" ]; then PLATFORM="arm64-v8a"; fi && \
    curl -L -H "Cache-Control: no-cache" -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${PLATFORM}.zip" && \
    unzip /tmp/xray.zip -d /usr/bin/xray && \
    chmod +x /usr/bin/xray/xray && \
    rm /tmp/xray.zip

# 3. 直接在 Dockerfile 中创建 Xray 配置文件
# 使用 VLESS 协议，入站端口 54321
RUN printf '{\n\
  "log": {"loglevel": "warning"},\n\
  "inbounds": [{\n\
    "port": 54321,\n\
    "protocol": "vless",\n\
    "settings": {\n\
      "clients": [{"id": "%s", "level": 0}],\n\
      "decryption": "none"\n\
    },\n\
    "streamSettings": {\n\
      "network": "ws",\n\
      "wsSettings": {"path": "/vless"}\n\
    }\n\
  }],\n\
  "outbounds": [{"protocol": "freedom"}]\n\
}' "$UUID" > /etc/xray/config.json

# 4. 直接在 Dockerfile 中创建 Supervisor 配置文件
# 实现进程中断后自动重启
RUN printf '[supervisord]\n\
nodaemon=true\n\
user=root\n\
logfile=/dev/stdout\n\
logfile_maxbytes=0\n\
\n\
[program:xray]\n\
command=/usr/bin/xray/xray run -c /etc/xray/config.json\n\
autostart=true\n\
autorestart=true\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
' > /etc/supervisor.conf

# 暴露端口
EXPOSE 54321

# 启动命令
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor.conf"]
