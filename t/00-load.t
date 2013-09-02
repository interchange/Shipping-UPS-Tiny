#!perl -T
use 5.010000;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 9;

BEGIN {
    use_ok( 'Shipping::UPS::Tiny' ) || print "Bail out!\n";
    use_ok( 'Shipping::UPS::Tiny::Address');
    use_ok( 'Shipping::UPS::Tiny::Package');
    use_ok( 'Shipping::UPS::Tiny::CC');
    use_ok( 'Shipping::UPS::Tiny::Service');
    use_ok( 'Shipping::UPS::Tiny::ShipmentResponse');
    use_ok( 'Shipping::UPS::Tiny::QuantumView');
    use_ok( 'Shipping::UPS::Tiny::QuantumView::Response');
    use_ok( 'Shipping::UPS::Tiny::Rates');
}

diag( "Testing Shipping::UPS::Tiny $Shipping::UPS::Tiny::VERSION, Perl $], $^X" );
