# xray-railway-docker
railway SAAS xray proxy


说明：
单文件：通过 printf 指令将 config.json 和 supervisord.conf 的内容直接写入镜像文件系统，去掉了对外部 COPY 指令的依赖。

动态 UUID：使用了 ENV UUID 变量。如果你在 Railway 的环境变量设置中修改了 UUID 的值并重新部署，镜像内会使用新的 ID（注意：此处的 printf 是在构建时运行的，若需运行时修改建议在 CMD 中改用脚本启动）。

进程守卫：autorestart=true 确保了如果 xray 进程因为任何原因挂掉，supervisord 会在秒级时间内将其重新拉起。

日志分流：将 Xray 的日志重定向到了 /dev/stdout，这样你可以直接在 Railway 的控制面板（Logs 选项卡）实时查看到 Xray 的运行日志。

部署建议：
在 Railway 部署时，请确保在 Settings -> Networking 中，将 Public Port 设置为 54321，这样外部流量才能通过该端口进入容器。
