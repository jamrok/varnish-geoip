Varnish Geo-IP VCL
===========================

Last updated: 2014-02-12

Here you will find a VCL config file for Varnish (http://varnish-cache.org)
This VCL will transparently add a HTTP request header with Geo-IP information
depending on the client IP address that made the request.

*** WARNING ***
This VCL consists of C code. Your Varnish might explode. YMMV.
Don't use it in production if you don't know what you're doing.
We are using it in production, but we _don't_ know what we're doing :).

Why would you want this?
------------------------
So your backend application can just read a HTTP header and figure out
where the client comes from, city, country and latitude/longitude.
Of course this doesn't come for free. You need the city edition of Geo-IP.

OR you can use the Lite Edition.

The rewritten header is "X-Geo-IP".

This product includes GeoLite data created by MaxMind, available from
<a href="http://www.maxmind.com">http://www.maxmind.com</a>.

X-Geo-IP header content
-----------------------

the `X-Geo-IP` header will differ depending on which function
you decide to apply, and what GeoIP database you are using, Country or City
edition.

In case of simple country lookup, you will have:

    X-Geo-IP: country:US

whereas a failed lookup will return `country:A6`. That is an internal
convention we adopted, of course YMMV.

In case of City database, the header will look like:

    X-Geo-IP: city:Rome, country:IT, lat:44.2134, lon:12.241, ip:1.2.3.4

(numbers are made up), while in the lookup failed case, you will have:

    X-Geo-IP: city:, country:A6, lat:0.0, lon:0.0, ip:1.2.3.4

The invalid/internal IP case is covered by the geoip library itself, so
it should be reported as unknown IP.

Requirements
------------

RPM Packages:

    git
    gcc
    make
    perl-Test-Harness
    perl-Test-Simple
    perl-JSON-XS
    GeoIP-devel

Map Data:

    GeoIP City (more accurate: http://www.maxmind.com/en/city)
    GeoLiteCity (Free 'lite' version)


Instructions
-------------

1) Install the relevant packages and GeoLiteCity.dat file, compile and test.

Tested with Varnish 3.0.5 on CentOS 5.10 and 6.5

Do the following as the [ root ] user:

    cd /root && \
    yum install -y git gcc make perl-Test-Harness perl-Test-Simple perl-JSON-XS GeoIP-devel && \
    wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz -O /root/GeoLiteCity.dat.gz && \
    gunzip /root/GeoLiteCity.dat.gz && \
    mv -vi GeoLiteCity.dat /usr/share/GeoIP/GeoLiteCity.dat && \
    ln -s /usr/share/GeoIP/{GeoLiteCity.dat,GeoIPCity.dat} && \
    ls -l /usr/share/GeoIP/{GeoLiteCity.dat,GeoIPCity.dat} && \
    git clone https://github.com/jamrok/varnish-geoip.git && \
    cd varnish-geoip && \
    make clean && make && make test && \
    cp -vip /root/varnish-geoip/geoip.vcl /etc/varnish/geoip.vcl

You should see "All tests successful" at the end of the execution

2) You can also manually check the geoip by running:

    /root/varnish-geoip/geoip 173.203.44.122

    OUTPUT:
    city:San Antonio, country:US, lat:29.488899, lon:-98.398697, ip:173.203.44.122

3) Update the Varnish Startup Config file [ /etc/sysconfig/varnish ] and add the parameter flag:

    -p 'cc_command=exec cc -fpic -shared -Wl,-x -L/usr/include/GeoIP.h -lGeoIP -o %o %s'

Example:

    DAEMON_OPTS="-a :6081 \
                 -T localhost:6082 \
                 -f /etc/varnish/default.vcl \
                 -S /etc/varnish/secret \
                 -s malloc,100M \
                 -p 'cc_command=exec cc -fpic -shared -Wl,-x -L/usr/include/GeoIP.h -lGeoIP -o %o %s'"

OR (watch out for the backslash at the end as shown below)

    DAEMON_OPTS="-a ${VARNISH_LISTEN_ADDRESS}:${VARNISH_LISTEN_PORT} \
                 -f ${VARNISH_VCL_CONF} \
                 -T ${VARNISH_ADMIN_LISTEN_ADDRESS}:${VARNISH_ADMIN_LISTEN_PORT} \
                 -t ${VARNISH_TTL} \
                 -w ${VARNISH_MIN_THREADS},${VARNISH_MAX_THREADS},${VARNISH_THREAD_TIMEOUT} \
                 -u varnish -g varnish \
                 -S ${VARNISH_SECRET_FILE} \
                 -p 'cc_command=exec cc -fpic -shared -Wl,-x -L/usr/include/GeoIP.h -lGeoIP -o %o %s' \
                 -s ${VARNISH_STORAGE}"


4) Add the following to the top of the Varnish VCL [/etc/varnish/default.vcl]:

    #-- Include to load Geo-IP functions
    include "/etc/varnish/geoip.vcl";

Add to top of vcl_recv function in Varnish VCL [/etc/varnish/default.vcl]:

    #-- Get Geo-IP Header info
    C{
      // The function below sets the [ req.http.X-Geo-IP ] header
      vcl_geoip_set_header(sp);
    }C

    #-- WARNING: Don't chain the X-Forwarded-For header or the above will not work correctly.
    #-- i.e. Don't: do the following:
    #-----   set req.http.X-Forwarded-For =
    #-----       req.http.X-Forwarded-For + ", " + client.ip;

    #-- Parse [ req.http.X-Geo-IP ] and set the relevant Geo-IP Headers:
    set req.http.X-Geo-City = regsub(req.http.X-Geo-IP, "(?i).*city:(.*), country.*","\1");
    set req.http.X-Geo-Country = regsub(req.http.X-Geo-IP, "(?i).*country:(.*), lat.*","\1");
    set req.http.X-Geo-Lat = regsub(req.http.X-Geo-IP, "(?i).*lat:(.*), lon.*","\1");
    set req.http.X-Geo-Lon = regsub(req.http.X-Geo-IP, "(?i).*lon:(.*), ip.*","\1");
    set req.http.X-Geo-IPAddr = regsub(req.http.X-Geo-IP, "(?i).*ip:(.*)","\1");

Add to top of vcl_fetch function in Varnish VCL [/etc/varnish/default.vcl] if you would like to set and send the headers to the client (good for testing)

    #-- Set the relevant Geo-IP headers
    set beresp.http.X-Geo-City = req.http.X-Geo-City;
    set beresp.http.X-Geo-Country = req.http.X-Geo-Country;
    set beresp.http.X-Geo-Lat = req.http.X-Geo-Lat;
    set beresp.http.X-Geo-Lon = req.http.X-Geo-Lon;
    set beresp.http.X-Geo-IPAddr = req.http.X-Geo-IPAddr;

    #-- Show the full Geo-IP header (unparsed)
    set beresp.http.X-Geo-IP = req.http.X-Geo-IP;

    #-- Show forwarded IP if it's set
    if (req.http.X-Forwarded-For) {
       set beresp.http.x-forwarded-for = req.http.x-forwarded-for;
    }


5) Check Varnish syntax and restart Varnish.

Normally you would test the varnish config by running the following command:

    varnishd -Cf /etc/varnish/default.vcl >/dev/null && \
    service varnish restart

However, we have to modify that command to include the parameters for geoip:

    varnishd -Cf /etc/varnish/default.vcl -p 'cc_command=exec cc -fpic -shared -Wl,-x -L/usr/include/GeoIP.h -lGeoIP -o %o %s' >/dev/null && \
    service varnish restart


6) Test by connecting to your server running Varnish (directly or via load balancer).

Curl directly to server's IP:

    curl -sIL http://50.X.Y.Z 

    CURL OUTPUT:
    Accept-Ranges: bytes
    Age: 0
    Connection: keep-alive
    Content-Type: text/html; charset=UTF-8
    Date: Thu, 13 Feb 2014 04:58:31 GMT
    HTTP/1.1 200 OK
    Server: Apache
    Via: 1.1 varnish
    X-Geo-City: San Antonio
    X-Geo-Country: US
    X-Geo-IPAddr: 162.X.Y.Z 
    X-Geo-IP: city:San Antonio, country:US, lat:29.488899, lon:-98.398697, ip:162.X.Y.Z 
    X-Geo-Lat: 29.488899
    X-Geo-Lon: -98.398697
    X-Varnish: 281599741

Curl to server via Load Balancer's IP (Note the X-Forwarded-For header is set):

    curl -sIL http://165.X.Y.Z 

    CURL OUTPUT:
    Accept-Ranges: bytes
    Age: 0
    Connection: Keep-Alive
    Content-Type: text/html; charset=UTF-8
    Date: Thu, 13 Feb 2014 04:58:12 GMT
    HTTP/1.1 200 OK
    Server: Apache
    Transfer-Encoding: chunked
    Via: 1.1 varnish
    X-Forwarded-For: 23.X.Y.Z 
    X-Geo-City: San Antonio
    X-Geo-Country: US
    X-Geo-IPAddr: 23.X.Y.Z 
    X-Geo-IP: city:San Antonio, country:US, lat:29.488899, lon:-98.398697, ip:23.X.Y.Z 
    X-Geo-Lat: 29.488899
    X-Geo-Lon: -98.398697
    X-Varnish: 281599740

7) ?

8) Profit !!

