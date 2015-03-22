pathfinder
===========
A local DNS service to deliver request to right place depending on if it's supposed to be censored

Setup
------

1. setup dnscrypt-proxy at port 40
1. run this script 
1. run dnsmasq and set upstream to this service
1. point system dns to 127.0.0.1


Thanks to
----------

- rubydns
- unbound
- dnsmasq
- dnscrypt-proxy
- dnscrypt-wrapper
- https://github.com/clowwindy/ChinaDNS
- https://github.com/Leask/Flora_Pac
