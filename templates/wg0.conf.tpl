[Interface]
Address = __WG_SERVER_IP__/24
ListenPort = __WIREGUARD_PORT__
PrivateKey = __WG_SERVER_PRIVATE_KEY__
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = __WG_CLIENT_PUBLIC_KEY__
AllowedIPs = __WG_CLIENT_IP__/32
