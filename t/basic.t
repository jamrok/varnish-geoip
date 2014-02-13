#!/usr/bin/env perl

#
# Basic varnish-geoip tests
#

use strict;
require test;

my @ip = (
    [ '213.236.208.22' => 'NO' => 'Oslo' ],
    [ '173.203.44.122' => 'US' => 'San Antonio' ],
    [ '37.202.6.117' => 'DE' => 'Mittwald' ],
    # Test an undefined case. Country should be "A6"
    [ '172.16.0.0'      => 'A6' => '' ],
);

Test::More::plan(tests => 1 + (2 * @ip));

test::update_binary();

# Basically test for supported languages
for (@ip) {
    my ($ip, $country, $city) = @{ $_ };
    test::is_country($ip, $country);
    test::is_city($ip, $city);
}

