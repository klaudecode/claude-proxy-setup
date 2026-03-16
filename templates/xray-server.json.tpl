{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "tag": "socks-in",
    "listen": "__WG_SERVER_IP__",
    "port": __XRAY_PORT__,
    "protocol": "socks",
    "settings": { "auth": "noauth", "udp": true },
    "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
  }],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "http",
      "settings": {
        "servers": [{
          "address": "__BRIGHT_DATA_HOST__",
          "port": __BRIGHT_DATA_PORT__,
          "users": [{
            "user": "__BRIGHT_DATA_USER__",
            "pass": "__BRIGHT_DATA_PASS__"
          }]
        }]
      }
    },
    { "tag": "direct", "protocol": "freedom" }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [{ "type": "field", "outboundTag": "proxy", "network": "tcp,udp" }]
  }
}
