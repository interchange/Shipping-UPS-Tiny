#!perl -T
use 5.010001;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Shipping::UPS::Tiny' ) || print "Bail out!\n";
}

diag( "Testing Shipping::UPS::Tiny $Shipping::UPS::Tiny::VERSION, Perl $], $^X" );
