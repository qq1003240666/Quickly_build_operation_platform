a# 项目介绍

 本项目意在帮你快速使用虚拟机和docker-compose 搭建一个专属运维你平台方便后续维护和测试命令



# 项目包含以下软件

## 基础环境

- docker&docker-compose
- k8s
- 常用基础软件包

## 运行环境

- python

- tomcat
- java

## 网关

- nginx
- apisix

## 数据库

- mysql
- postgress
- redis
- mongodb

## 中间件

- kafka
- zk

## 监控

- prometheus
- alertmanager
- pushgateway
- grafana

## devops

- gitlab

- jenkins

- ELK
- jumpserver
- harbor



## 便于使用

- frp
- leanote
- mayfly-go
- clash



# 环境介绍

- 操作系统 Ubuntu 22.04.4 LTS
- 资源 8c 16g
- 磁盘 100G

# 环境初始化



1. 安装操作系统

   下载iso镜像 https://cn.ubuntu.com/download/server/thank-you?version=24.04&architecture=amd64

   安装操作系统 

2. 初始化系统

   1. 修改密码

      ```
      # 允许root 登录 设置root 密码
      sudo passwd root
      ```

   2. 设置固定网卡

      ```
      cat > /etc/netplan/00-installer-config.yaml << EOF
      # This is the network config written by 'subiquity'
      network:
        version: 2
        ethernets:
          ens33:
            addresses:
            - 192.168.2.70/24
            gateway4: 192.168.2.1
            nameservers:
              addresses: [8.8.8.8,114.114.114.114]
      EOF
      systemctl restart NetworkManager
      ```

      

   3. 关闭防火墙

      ```
      systemctl stop ufw
      ```

   4. 配置ssh

      ```
      # 运行root ssh登录
      echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
      echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
      systemctl restart sshd
      ```

## 安装运维常用软件

```
sudo apt install net-tools  supervisor iperf iftop ifstat 
# supervisor 守护进程
# iperf 压测网络
# iftop 查看各进程网络IO
# ifstat 显示网络接口的接收和发送速度

# 安装各种客户端
sudo apt install git mysql-client postgresql-client
```

## 安装docker

```
# 卸载docker
sudo apt remove docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
# 安装依赖项
sudo apt install ca-certificates curl gnupg lsb-release
# 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
# 安装docker
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose

# 更换镜像源
cat > /etc/docker/daemon.json << EOF
{
        "registry-mirrors": [
        "https://ghcr.nju.edu.cn",
        "https://docker.1panel.live"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## 安装minikube

```
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

minikube start --force --driver=none --kubernetes-version=v1.23.3 --image-repository='registry.cn-hangzhou.aliyuncs.com/google_containers' --image-mirror-country='cn'

mv /root/.kube /root/.minikube $HOME
chown -R $USER $HOME/.kube $HOME/.minikube

# 安装kubectl
curl -LO "https://dl.k8s.io/release/v1.23.3/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/bin/
```

# 进行配置

```
mkdir -p /opt/
git clone https://github.com/qq1003240666/Quickly_build_operation_platform.git

# 查看默认配置
vim config.ini
mysql_password=1234567
postgress_password=123456
redis_password=123456aaaa
mongodb_password=123456


```



# 进行部署

```
cd /opt/Quickly_build_operation_pla	tform
./install.sh



# 替换mysql 密码
mysql_password=`cat config.ini | grep mysql_password | awk -F "=" '{print $2}'`
sed -i "s/MYSQL_ROOT_PASSWORD:.*/MYSQL_ROOT_PASSWORD: $mysql_password/" ./app/db/mysql/docker-compose.yaml
sed -i "s/password=.*/password=$mysql_passwd/" ./app/db/mysql/mysql_export_conf/my.cnf

# 替换postgress 密码
postgress_password=`cat config.ini | grep postgress_password | awk -F "=" '{print $2}'`
sed -i "s/POSTGRES_PASSWORD:.*/POSTGRES_PASSWORD: $postgress_password/g" ./app/db/postgresql/docker-compose.yaml
sed -i "s/DATA_SOURCE_NAME:.*/DATA_SOURCE_NAME: \"postgresql:\/\/postgres:$postgress_password@postgresql:5432\/?sslmode=disable\"/" ./app/db/postgresql/docker-compose.yaml


# 替换redis密码
redis_password=`cat config.ini | grep redis_password | awk -F "=" '{print $2}'`
sed -i "s/redis.password=.*/redis.password=$redis_password/" ./app/db/redis/docker-compose.yaml
sed -i "s/requirepass.*/requirepass $redis_password/" ./app/db/redis/redis_conf/redis.conf

# 替换mongodb密码
chmod 777 ./app/db/mongodb/tmp
mongodb_password=`cat config.ini | grep mongodb_password | awk -F "=" '{print $2}'`
sed -i "s/MONGO_INITDB_ROOT_PASSWORD:.*/MONGO_INITDB_ROOT_PASSWORD: $mongodb_password/g" ./app/db/mongodb/docker-compose.yaml
sed -i "s/MONGODB_URI:.*/MONGODB_URI: mongodb:\/\/root:$mongodb_password@mongodb:27017\/:?authSource=admin/g" ./app/db/mongodb/docker-compose.yaml




```




