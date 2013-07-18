#!perl -T
use 5.010000;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 6;

BEGIN {
    use_ok( 'Shipping::UPS::Tiny' ) || print "Bail out!\n";
    use_ok( 'Shipping::UPS::Tiny::Address');
    use_ok( 'Shipping::UPS::Tiny::Package');
    use_ok( 'Shipping::UPS::Tiny::CC');
    use_ok( 'Shipping::UPS::Tiny::Service');
    use_ok( 'Shipping::UPS::Tiny::ShipmentResponse');
}

diag( "Testing Shipping::UPS::Tiny $Shipping::UPS::Tiny::VERSION, Perl $], $^X" );
