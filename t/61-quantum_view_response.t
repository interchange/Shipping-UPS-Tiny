
use strict;
use warnings;
use Shipping::UPS::Tiny::QuantumView::Response;
use File::Spec::Functions;
use Data::Dumper;
use File::Slurp qw/read_file/;
use Test::More;

# here we need a xml file

my $testfile = catfile(t => 'quantum-data' => 'unread.xml');
if (-f $testfile) {
    plan tests => 7;
}
else {
    plan skip_all => 'No xml file found for testing!. It should be produced by the 60-quantum_view.t testfile';
}

ok(-f $testfile);

# in 60-quantum_view.t we already tested that passing a HTTP::Response
# works. Now we have to be sure that passing a filename or an ref to a
# scalar works the same.


my %testfiles;
foreach (qw/unread failure days/) {
    $testfiles{$_} = catfile(t => 'quantum-data', $_ . '.xml');
}

foreach my $t (keys %testfiles) {
    my $filename = $testfiles{$t};
    my $obj = Shipping::UPS::Tiny::QuantumView::Response->new(response => $filename);
    ok($obj->response_section, "Got parsed data with filename: $filename");
    # then we try with a ref
    my $xmlbody = read_file($filename);
    $obj = Shipping::UPS::Tiny::QuantumView::Response->new(response => \$xmlbody);
    ok($obj->response_section, "Got parsed data with ref scalar from $filename");
}
