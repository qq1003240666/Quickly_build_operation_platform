#!/bin/bash

# 初始化机器

print (){
echo '#######################################'
echo $1
echo '#######################################'
}


print '0. 确认配置'
print '请查看config配置正确'
cat config.ini

print '加载config.ini'
current_dir=`pwd`
Host_ip=`ifconfig eth0 | grep netmask | awk '{print $2}'`
mysql_password=`cat $current_dir/config.ini | grep mysql_password | awk -F "=" '{print $2}'`
postgresql_password=`cat $current_dir/config.ini | grep postgresql_password | awk -F "=" '{print $2}'`
redis_password=`cat $current_dir/config.ini | grep redis_password | awk -F "=" '{print $2}'`
mongodb_password=`cat $current_dir/config.ini | grep mongodb_password | awk -F "=" '{print $2}'`

read -p '请输入安装目录:' install_dir
if [ ! -d $install_dir ] ; then
echo "输入目录不存在 使用安装目录使用默认 /root/app"
install_dir=/root/app
fi

print '1. 初始化机器'
print '    关闭防火墙'
systemctl stop ufw


print '    安装常用基础包'
sudo apt update
sudo apt install -y net-tools  supervisor iperf iftop ifstat git mysql-client postgresql-client ca-certificates curl gnupg lsb-release python3 python3-pip
ln -s /bin/python /bin/python3

print '安装docker'
docker --version 
if [ $? != 0 ] ; then
sudo apt remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#curl -fsSL https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose
cat > /etc/docker/daemon.json << EOF
{
        "registry-mirrors": [
        "https://ghcr.nju.edu.cn",
        "https://docker.1panel.live"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
docker --version
else
systemctl restart docker
echo '	docker服务已安装'
fi


print '2. 安装部署网关产品'
print '部署nginx'
mkdir -p $install_dir/gateway/nginx/nginx_conf $install_dir/gateway/nginx/nginx_data $install_dir/gateway/nginx/nginx_log
cp -rf $current_dir/gateway/nginx/docker-compose.yaml $install_dir/gateway/nginx/docker-compose.yaml
cp -rf $current_dir/gateway/nginx/nginx_conf/status.conf $install_dir/gateway/nginx/nginx_conf/
cd $install_dir/gateway/nginx/
docker-compose down
docker-compose up -d
print '部署nginx完成'


print '部署apisix'
mkdir -p $install_dir/gateway/apisix/apisix_conf $install_dir/gateway/apisix/apisix_data/lua $install_dir/gateway/apisix/apisix_etcd/data $install_dir/gateway/apisix/apisix_dashboard_conf
cp -rf $current_dir/gateway/apisix/docker-compose.yaml $install_dir/gateway/apisix/docker-compose.yaml
cp -rf $current_dir/gateway/apisix/apisix_conf/config.yaml $install_dir/gateway/apisix/apisix_conf/config.yaml
cp -rf $current_dir/gateway/apisix/apisix_dashboard_conf/dashboard.yaml $install_dir/gateway/apisix/apisix_dashboard_conf/dashboard.yaml
cd $install_dir/gateway/apisix/
docker-compose down
docker-compose up -d


print '3. 安装部署数据库产品'
print '部署mysql'
mkdir -p $install_dir/db/mysql/mysql_conf $install_dir/db/mysql/mysql_data $install_dir/db/mysql/mysql_export_conf
cp -rf $current_dir/db/mysql/docker-compose.yaml $install_dir/db/mysql/docker-compose.yaml
cp -rf $current_dir/db/mysql/mysql_conf/my.cnf $install_dir/db/mysql/mysql_conf/my.cnf
cp -rf $current_dir/db/mysql/mysql_export_conf/my.cnf $install_dir/db/mysql/mysql_export_conf/my.cnf
sed -i "s/MYSQL_ROOT_PASSWORD:.*/MYSQL_ROOT_PASSWORD: $mysql_password/" $install_dir/db/mysql/docker-compose.yaml
sed -i "s/password=.*/password=$mysql_passwd/" $install_dir/db/mysql/mysql_export_conf/my.cnf
cd $install_dir/db/mysql/
docker-compose down
docker-compose up -d
echo "mysql -h127.0.0.1 -uroot -p$mysql_password" > /bin/mysql_connect
chmod +x /bin/mysql_connect


print '部署redis'
mkdir -p $install_dir/db/redis/redis_conf $install_dir/db/redis/redis_data
cp -rf $current_dir/db/redis/docker-compose.yaml $install_dir/db/redis/docker-compose.yaml
cp -rf $current_dir/db/redis/redis_conf/redis.conf $install_dir/db/redis/redis_conf/redis.conf
sed -i "s/redis.password=.*/redis.password=$redis_password/" $install_dir/db/redis/docker-compose.yaml
sed -i "s/requirepass.*/requirepass $redis_password/" $install_dir/db/redis/redis_conf/redis.conf
cd $install_dir/db/redis
docker-compose down
docker-compose up -d
echo "redis-cli -h 127.0.0.1 -p 6379 -a $redis_password" > /bin/redis_connect
chmod +x /bin/redis_connect


print '部署postgresql'
mkdir -p $install_dir/db/postgresql/postgresql_data $install_dir/db/postgresql/postgresql_log
cp -rf $current_dir/db/postgresql/docker-compose.yaml $install_dir/db/postgresql/docker-compose.yaml
sed -i "s/POSTGRES_PASSWORD:.*/POSTGRES_PASSWORD: $postgresql_password/g" $install_dir/db/postgresql/docker-compose.yaml
sed -i "s/DATA_SOURCE_NAME:.*/DATA_SOURCE_NAME: \"postgresql:\/\/postgres:$postgresql_password@postgresql:5432\/?sslmode=disable\"/" $install_dir/db/postgresql/docker-compose.yaml
cd $install_dir/db/postgresql
docker-compose down
docker-compose up -d



print '部署mongodb'
mkdir -p $install_dir/db/mongodb/mongodb_data
cp -rf $current_dir/db/mongodb/docker-compose.yaml $install_dir/db/mongodb/docker-compose.yaml
sed -i "s/MONGO_INITDB_ROOT_PASSWORD:.*/MONGO_INITDB_ROOT_PASSWORD: $mongodb_password/g" $install_dir/db/mongodb/docker-compose.yaml
sed -i "s/MONGODB_URI:.*/MONGODB_URI: mongodb:\/\/root:$mongodb_password@mongodb:27017\/:?authSource=admin/g" $install_dir/db/mongodb/docker-compose.yaml
cd $install_dir/db/mongodb/
docker-compose down
docker-compose up -d



print '4. 安装部署中间件'
print '部署kafka'
mkdir -p $install_dir/middleware/kafka/zk
cp -rf $current_dir/middleware/kafka/docker-compose.yaml $install_dir/middleware/kafka/docker-compose.yaml
cd $install_dir/middleware/kafka
docker-compose down
docker-compose up -d


print '5. 安装部署监控'
print '部署prometheus'
mkdir -p $install_dir/monitor/prometheus/prometheus_conf  $install_dir/monitor/prometheus/alertmanager_conf $install_dir/monitor/prometheus/grafana_data $install_dir/monitor/prometheus/prometheus_data
cp -rf $current_dir/monitor/prometheus/docker-compose.yaml $install_dir/monitor/prometheus/docker-compose.yaml
cp -rf $current_dir/monitor/prometheus/prometheus_conf/* $install_dir/monitor/prometheus/prometheus_conf/
cp -rf $current_dir/monitor/prometheus/alertmanager_conf/* $install_dir/monitor/prometheus/alertmanager_conf/
chmod 777 $install_dir/monitor/prometheus/prometheus_conf $install_dir/monitor/prometheus/alertmanager_conf $install_dir/monitor/prometheus/grafana_data $install_dir/monitor/prometheus/prometheus_data
cd $install_dir/monitor/prometheus
docker-compose down
docker-compose up -d


print '6. 安装部署devops'
print '部署gitlab'
mkdir -p $install_dir/devops/gitlab/gitlab_data $install_dir/devops/gitlab/gitlab_logs $install_dir/devops/gitlab/gitlab_conf
cp -rf $current_dir/devops/gitlab/docker-compose.yaml $install_dir/devops/gitlab/docker-compose.yaml
chmod -R 755 $install_dir/devops/gitlab/gitlab_data
cd $install_dir/devops/gitlab
docker-compose down
#docker-compose up -d
#gitlab_password=`docker exec -it gitlab cat /etc/gitlab/initial_root_password | grep ^Password | awk '{print $2}'`
#sed -i "s/gitlab_password=.*/gitlab_password=$gitlab_password/g" $current_dir/config.ini


print '部署jenkins'
mkdir -p $install_dir/devops/jenkins/jenkins_home
cp -rf $current_dir/devops/jenkins/docker-compose.yaml $install_dir/devops/jenkins/docker-compose.yaml
cd $install_dir/devops/jenkins
docker-compose down
#docker-compose up -d
#jenkins_password=`docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
#sed -i "s/jenkins_password=.*/jenkins_password=$jenkins_password" $current_dir/config.ini


print '部署jumpserver'
mkdir -p $install_dir/devops/jumpserver/jumpserver_data $install_dir/devops/jumpserver/mysql_data $install_dir/devops/jumpserver/redis_data $install_dir/devops/jumpserver/redis_conf
cp -rf $current_dir/devops/jumpserver/docker-compose.yaml $install_dir/devops/jumpserver/docker-compose.yaml
cp -rf $current_dir/devops/jumpserver/redis_conf/redis.conf $install_dir/devops/jumpserver/redis_conf/redis.conf

sed -i "s/DB_PASSWORD:.*/DB_PASSWORD: $mysql_password/g" $install_dir/devops/jumpserver/docker-compose.yaml
sed -i "s/MYSQL_ROOT_PASSWORD:.*/MYSQL_ROOT_PASSWORD: $mysql_password/g" $install_dir/devops/jumpserver/docker-compose.yaml
sed -i "s/REDIS_PASSWORD:.*/REDIS_PASSWORD: $redis_password/g" $install_dir/devops/jumpserver/docker-compose.yaml
sed -i "s/requirepass.*/requirepass $redis_password/g" $install_dir/devops/jumpserver/redis_conf/redis.conf
cd $install_dir/devops/jumpserver
rm -rf $install_dir/devops/jumpserver/mysql_data/*
docker-compose down
docker-compose up -d mysql
docker-compose up -d redis
sleep 10
mysql -h127.0.0.1 -uroot -P 3307 -p$mysql_password -e "create database jumpserver default charset 'utf8';"
mysql -h127.0.0.1 -uroot -P 3307 -p$mysql_password -e "create user 'jumpserver'@'%' IDENTIFIED WITH mysql_native_password by '$mysql_password';"
mysql -h127.0.0.1 -uroot -P 3307 -p$mysql_password -e "grant all on jumpserver.* to 'jumpserver'@'%';"
mysql -h127.0.0.1 -uroot -P 3307 -p$mysql_password -e "flush privileges;"
if [ $? != 0 ] ; then
       echo "执行未成功 请稍后自行重试"
fi       
cd $install_dir/devops/jumpserver
docker-compose up -d


print '7. 安装部署方便的APP'
print '部署clash'
mkdir -p $install_dir/fb_app/clash/
cp -rf $current_dir/fb_app/clash/* $install_dir/fb_app/clash
cat > /usr/lib/systemd/system/clash.service << EOF
[Unit]
Description=clash daemon

[Service]
Type=simple
User=root
ExecStart=$install_dir/fb_app/clash/clash -d $install_dir/fb_app/clash/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl restart clash
cd $install_dir/fb_app/clash/
docker-compose down
docker-compose up -d


print '部署mayfly'
mkdir -p $install_dir/fb_app/mayfly-go/mayfly/rec $install_dir/fb_app/mayfly-go/mysql_data
cp -rf $current_dir/fb_app/mayfly-go/docker-compose.yaml $install_dir/fb_app/mayfly-go/docker-compose.yaml
cp -rf $current_dir/fb_app/mayfly-go/mayfly-go.sql $install_dir/fb_app/mayfly-go/mayfly-go.sql
cp -rf $current_dir/fb_app/mayfly-go/mayfly/config.yml $install_dir/fb_app/mayfly-go/mayfly/config.yml
touch $install_dir/fb_app/mayfly-go/mayfly/mayfly-go.log
cd $install_dir/fb_app/mayfly-go/
sed -i "s/MYSQL_ROOT_PASSWORD:.*/MYSQL_ROOT_PASSWORD: $mysql_password/g" $install_dir/fb_app/mayfly-go/docker-compose.yaml
sed -i "s/password:.*/password: $mysql_password/g" $install_dir/fb_app/mayfly-go/mayfly/config.yml
docker-compose up -d mysql
sleep 10
mysql -h127.0.0.1 -uroot -P 3308 -p$mysql_password -e 'CREATE DATABASE `mayfly-go`'
mysql -h127.0.0.1 -uroot -P 3308 -p$mysql_password mayfly-go < $install_dir/fb_app/mayfly-go/mayfly-go.sql
docker-compose down
docker-compose up -d 


print '部署leanote'
mkdir -p $install_dir/fb_app/leanote/data
cp -rf $current_dir/fb_app/leanote/docker-compose.yaml $install_dir/fb_app/leanote/docker-compose.yaml
cd $install_dir/fb_app/leanote/
docker-compose down
docker-compose up -d 

print '部署jupyter'
mkdir /root/jupyter
pip install jupyterlab notebook jupyterlab-language-pack-zh-CN
jupyter-server --generate-config
echo '''
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.allow_root = True
c.ServerApp.notebook_dir = '/root/jupyter'
''' >> /root/.jupyter/jupyter_server_config.py
cat > /usr/lib/systemd/system/jupyter.service << EOF
[Unit]
Description=Jupyter Management
After=network.target

[Service]
User=root
Group=root
ExecStart= jupyter-notebook --no-browser

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl restart jupyter



echo '''
-------------------------------------------------------------------------------------------------------------------------------------
网关产品              镜像版本                                  暴漏端口            账号密码                  备注
nginx                 nginx:1.22                                80                  /
apisix                apache/apisixlatest	                9080|9180           /
  apisix-etcd         quay.io/coreos/etcdv3.5.5 /               /
  apisix-dashboard    apache/apisix-dashboard3.0.0-alpine       9000|9001           admin/admin
-------------------------------------------------------------------------------------------------------------------------------------
数据库产品            镜像版本                                  暴漏端口            账号密码                  备注	
mysql                 mysql:8                                   3306                root/$mysql_password      mysql_connect 直接连
postgresql            postgres:15.7                             5432                root/$postgresql_password postgres_connect 直接连
redis                 redis:7.0.8                               6379	            $redis_password           redis_connect 直接连
mongodb	              mongo:8                                   27017	            $mongodb_password         mongo 直接连
-------------------------------------------------------------------------------------------------------------------------------------
中间件产品            镜像版本                                  暴漏端口            账号密码                  备注	
kafka                 wurstmeister/kafka                        9092                /
  kafka-zookeeper     wurstmeister/zookeeper                    12181               /
  kafka-ui            provectuslabs/kafka-ui                    19092               /
-------------------------------------------------------------------------------------------------------------------------------------
监控产品              镜像版本                                  暴漏端口            账号密码                  备注	
prometheus            prom/prometheus                           9090                /                         已添加部分metrics
alertmanager          prom/alertmanager                         9093                /
grafana               grafana/grafana                           3000                admin/admin
pushgateway           prom/pushgateway                          9091                /
-------------------------------------------------------------------------------------------------------------------------------------
devops产品            镜像版本                                  暴漏端口            账号密码                  备注	
gitlab-ce             gitlab/gitlab-ce                          8000                $gitlab_password          默认不启动
jenkins               jenkins/jenkins:lts                       8001                $jenkins_password         默认不启动
jumpserver            jumpserver/jms_all:v2.16.0                2222|4080           admin/admin
 jumpserver-mysql     mysql:8                                    3307                $mysql_password
 jumpserver-redis     redis:7.0.8                                /                   $redis_password
-------------------------------------------------------------------------------------------------------------------------------------
便捷app               镜像版本                                  暴漏端口            账号密码                  备注	
clash                 /                                         7890|7891|12345     /                         systemctl 启动
  clash_yacd          ghcr.io/haishanh/yacdmaster               1234                $clash_token
mayfly-go             ccr.ccs.tencentyun.com/mayfly/mayfly-go:v1.8.5  18888         admin/admin123.
 mayfly-go-mysql      mysql:8                                    3308               $mysql_password
leanote               axboy/leanote                             19999               admin/abc123
jupyter-notebook      quay.io/jupyter/scipy-notebook:2024-10-07 8888                /                         评估没必要安装
-------------------------------------------------------------------------------------------------------------------------------------
监控组件              镜像版本                                  暴漏端口            账号密码                  备注	
nginx_export          nginx/nginx-prometheus-exporter           9113                /
mysql_export          prom/mysqld-exporter                      9104                /
postgresql_export     wrouesnel/postgres_exporter               9187                /
redis_export          oliver006/redis_exporter                  9121                /
mongodb_exporter      bitnami/mongodb-exporter                  9216                /
kafka_export          danielqsj/kafka-exporter                  9308                /
node_export           prom/node-exporter                        9100                /
cAdvisor              lagoudocker/cadvisor:v0.37.0              4194                /
-------------------------------------------------------------------------------------------------------------------------------------

''' >> $install_dir/readme.md
