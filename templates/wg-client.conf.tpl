[Interface]
PrivateKey = __WG_CLIENT_PRIVATE_KEY__
Address = __WG_CLIENT_IP__/24
DNS = 1.1.1.1

[Peer]
PublicKey = __WG_SERVER_PUBLIC_KEY__
Endpoint = __SSH_HOST__:__WIREGUARD_PORT__
AllowedIPs = __WG_ALLOWED_IPS__
PersistentKeepalive = 25
