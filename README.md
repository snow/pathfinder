pathfinder
===========
A PAC generator and A local DNS service, aiming to pick up services inside China
to bypass proxy, and send anyother tracffic into proxy.

Setup
------

1. setup dnscrypt-proxy at port 40
1. run dns_service.rb
1. run dnsmasq and set upstream to this service
1. point system dns to 127.0.0.1
1. run generate_pac.rb, then use the generated file on where you want


Thanks to
----------

- rubydns
- unbound
- dnsmasq
- dnscrypt-proxy
- dnscrypt-wrapper
- https://github.com/clowwindy/ChinaDNS
- https://github.com/Leask/Flora_Pac
