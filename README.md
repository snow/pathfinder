pathfinder
===========
A PAC generator and A local DNS service, 主要作用是让作者关心的那部分国内流量直连，其余走代理。使得在翻墙的同时，尽量减少作者常用的数量不多的几个国内网络服务受到的影响。

DNS分发的规则是白名单上的域名转发到国内DNS，其余走本机的 dnscrypt-proxy.

PAC的规则是:

1. isPlainHostName 直连
1. 白名单直连
1. Apple Push Notification, Facetime和Game Center的端口直连
1. 然后解析域名, 如果成功获得一个国内ip, 直连
1. 其余走代理

在解析域名这一步，因为DNS是白名单，所以白名单之外的域名，是送到墙外去解析的，墙内外都有ip的域名，会得到墙外的ip, 进而在PAC里选择走代理。
PAC部分大体上是把 Flora_Pac 翻译成了ruby. 

Setup
------

1. setup dnscrypt-proxy at port 40
1. run dns_service.rb
1. run dnsmasq and set upstream to this service
1. point system dns to 127.0.0.1
1. run generate_pac.rb, then use the generated file on where you want

### launchd
1. copy cc.firebloom.pathfinder.sample.plist to cc.firebloom.pathfinder.plist
1. change paths in plist
1. load that plist in launchd

为什么不用别的轮子
----------------
**曲径**
- 曲径的分发规则基于黑名单，一旦发现了新的被墙的域名，要等曲径的名单更新，或者自己去更新曲径的个人黑名单，很麻烦。
- 曲径的线路抽风的时候，我要切到别的隧道，那时就不能用曲径的PAC来做分发了。

**Flora PAC**
- 域名白名单硬编码在PAC模板里了，PAC模板又写在生成PAC的脚本里，如果fork Flora PAC然后修改，那么日后当Flora更新，pull过来的时候有相对大的概率会冲突。
- 生成PAC的逻辑很简单，移植的成本相当低。
- 个人在ruby上投了比python多的技能点，而ruby本身又更省事
综合下来，选择移植而不是fork.

**ChinaDNS**
- 我还没完全搞懂这东西的代码 /. .\

Thanks to
----------

- https://github.com/ioquatix/rubydns
- https://www.unbound.net/
- http://www.thekelleys.org.uk/dnsmasq/doc.html
- http://dnscrypt.org/
- https://github.com/Cofyc/dnscrypt-wrapper
- https://github.com/clowwindy/ChinaDNS
- https://github.com/Leask/Flora_Pac
