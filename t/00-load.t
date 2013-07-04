#!perl -T
use 5.010001;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'Shipping::UPS::Tiny' ) || print "Bail out!\n";
    use_ok( 'Shipping::UPS::Tiny::Address');
    use_ok( 'Shipping::UPS::Tiny::Package');
}

diag( "Testing Shipping::UPS::Tiny $Shipping::UPS::Tiny::VERSION, Perl $], $^X" );
