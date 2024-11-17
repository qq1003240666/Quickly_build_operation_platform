docker exec -it prometheus promtool check config /etc/prometheus/prometheus.yml
curl -X POST 127.0.0.1:9090/-/reload
