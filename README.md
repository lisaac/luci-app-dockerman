# Docker Manager interface for LuCI

## 适用于 LuCI 的 Docker 管理插件
用于管理 Docker 容器、镜像、网络，适用于自带 Docker 的 Openwrt系统、运行在 Docker 中的 openwrt 或 [LuCI-in-docker](https://github.com/lisaac/luci-in-docker).

### Depends/依赖
- docker-ce (optional, since you can use it as a remote docker client)
- luci-lib-jsonc
- [luci-lib-docker](https://github.com/lisaac/luci-lib-docker)
- ttyd (optional, use for container console)

### Compile/编译
```bash
./scripts/feeds update luci-lib-jsonc
./scripts/feeds install luci-lib-jsonc
mkdir -p package/luci-lib-docker && \
wget https://raw.githubusercontent.com/lisaac/luci-lib-docker/master/Makefile -O package/luci-lib-docker/Makefile
mkdir -p package/luci-app-dockerman && \
wget https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/Makefile -O package/luci-app-dockerman/Makefile

#compile package only
make package/luci-lib-jsonc/compile V=99
make package/luci-lib-docker/compile v=99
make package/luci-app-dockerman/compile v=99

#compile
make menuconfig
#choose Utilities  ---> <*> docker-ce....................................... Docker Community Edition
#choose Kernel features for Docker which you want
#choose LuCI ---> 3. Applications  ---> <*> luci-app-dockerman..... Docker Manager interface for LuCI ----> save
make V=99
```

### Download /下载
- [ipk file](https://github.com/lisaac/luci-app-dockerman/releases)

### Screenshot/截图
- Containers
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/containers.png)
- Container Info
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/container_info.png)
- Container Edit
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/container_edit.png)
- Container Stats
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/container_stats.png)
- Container Logs
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/container_logs.png)
- New Container
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/new_container.png)
- Images
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/images.png)
- Networks
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/networks.png)
- New Network
![](https://raw.githubusercontent.com/lisaac/luci-app-dockerman/master/doc/new_network.png)

### Thanks
- Chinese translation by [401626436](https://www.right.com.cn/forum/space-uid-382335.html)
