{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "tag": "socks-in",
    "listen": "127.0.0.1",
    "port": 1080,
    "protocol": "socks",
    "settings": { "auth": "noauth", "udp": true }
  }],
  "outbounds": [{
    "tag": "proxy",
    "protocol": "socks",
    "settings": {
      "servers": [{
        "address": "__XRAY_SERVER_ADDRESS__",
        "port": __XRAY_PORT__
      }]
    }
  }]
}
