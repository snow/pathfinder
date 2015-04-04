// extracted from Flora_Pac by @leaskh
// www.leaskh.com, i@leaskh.com

function FindProxyForURL(url, host) {

    var list = [
        "%home_ip_list%"
    ];

    var safeDomains = {
        "%safe_domains%"
    };

    // https://support.apple.com/en-us/HT202944
    var safePorts = {
        5223  : 1,
        3478  : 1,
        3479  : 1,
        3480  : 1,
        3481  : 1,
        3482  : 1,
        3483  : 1,
        3484  : 1,
        3485  : 1,
        3486  : 1,
        3487  : 1,
        3488  : 1,
        3489  : 1,
        3490  : 1,
        3491  : 1,
        3492  : 1,
        3493  : 1,
        3494  : 1,
        3495  : 1,
        3496  : 1,
        3497  : 1,
        16384 : 1,
        16385 : 1,
        16386 : 1,
        16387 : 1,
        16393 : 1,
        16394 : 1,
        16395 : 1,
        16396 : 1,
        16397 : 1,
        16398 : 1,
        16399 : 1,
        16400 : 1,
        16401 : 1,
        16402 : 1
    };

    var proxy = "%proxy%";

    function convertAddress(ipchars) {
        var bytes = ipchars.split('.');
        var result = ((bytes[0] & 0xff) << 24) |
                     ((bytes[1] & 0xff) << 16) |
                     ((bytes[2] & 0xff) <<  8) |
                      (bytes[3] & 0xff);
        return result;
    }

    function match(ip, list) {
        var left = 0, right = list.length;
        do {
            var mid = Math.floor((left + right) / 2),
                ipf = (ip & list[mid][1]) >>> 0,
                m   = (list[mid][0] & list[mid][1]) >>> 0;
            if (ipf == m) {
                return true;
            } else if (ipf > m) {
                left  = mid + 1;
            } else {
                right = mid;
            }
        } while (left + 1 <= right)
        return false;
    }

    function testDomain(target, domains, cnRootIncluded) {
        var idxA = target.lastIndexOf('.');
        var idxB = target.lastIndexOf('.', idxA - 1);
        var hasOwnProperty = Object.hasOwnProperty;
        var suffix = cnRootIncluded ? target.substring(idxA + 1) : '';
        if (suffix === 'cn') {
            return true;
        }
        while (true) {
            if (idxB === -1) {
                if (hasOwnProperty.call(domains, target)) {
                    return true;
                } else {
                    return false;
                }
            }
            suffix = target.substring(idxB + 1);
            if (hasOwnProperty.call(domains, suffix)) {
                return true;
            }
            idxB = target.lastIndexOf('.', idxB - 1);
        }
    }

    if (isPlainHostName(host)
     || host === '127.0.0.1'
     || host === 'localhost') {
        return 'DIRECT';
    }

    if (testDomain(host, safeDomains, true)) {
        return 'DIRECT';
    }

    if (safePorts[host.split(':')[1]]) {
        return 'DIRECT';
    }

    var strIp = dnsResolve(host);
    if (!strIp) {
        return proxy;
    }

    var intIp = convertAddress(strIp);
    if (match(intIp, list)) {
        return 'DIRECT';
    }

    return proxy;

}
