
use strict;
use warnings;
use Shipping::UPS::Tiny::QuantumView::Response;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;

# here we need a xml file

my $testfile = catfile(t => 'quantum-data.xml');
if (-f $testfile) {
    plan tests => 1;
}
else {
    plan skip_all => 'No xml file found for testing!. It should be produced by the 60-quantum_view.t testfile';
}

ok(-f $testfile);


