#-- Include to load Geo-IP functions
include "/etc/varnish/geoip.vcl";

backend default {
    .host = "localhost";
    .port = "8080";
}

sub vcl_recv {

    # Lookup IP only for the first request restart
    if (req.restarts == 0) {
        if (req.request == "GET" || req.request == "HEAD" || req.request == "POST") {
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
        }
    }

}

sub vcl_fetch {

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
}

