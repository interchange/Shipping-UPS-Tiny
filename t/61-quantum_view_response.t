
use strict;
use warnings;
use Shipping::UPS::Tiny::QuantumView::Response;
use File::Spec::Functions;
use Data::Dumper;
use XML::Compile::Schema;
use File::Slurp;
use Test::More;

# here we need a xml file

my $testfile = catfile(t => 'quantum-data' => 'unread.xml');
my $schemadir = catdir(qw/t QuantumView QuantumViewforPackage
                          QUANTUMVIEWXML Schemas/);

diag "Schema is in $schemadir";

if (-f $testfile && -d $schemadir) {
    plan tests => 44;
}
elsif (! -d $schemadir) {
    plan skip_all => "No schema directory found in $schemadir";
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

# fix and pick the right file
$testfiles{unread} = fix_bogus_data($testfiles{unread});

foreach my $t (keys %testfiles) {
    my $filename = $testfiles{$t};
    my $obj = Shipping::UPS::Tiny::QuantumView::Response->new(response => $filename,
                                                              schemadir => $schemadir);
    ok($obj->response_section, "Got parsed data with filename: $filename");
    is($obj->schemadir, $schemadir);
    # then we try with a ref
    my $xmlbody = read_file($filename);
    $obj = Shipping::UPS::Tiny::QuantumView::Response->new(response => \$xmlbody,
                                                           schemadir => $schemadir);
    ok($obj->response_section, "Got parsed data with ref scalar from $filename");
    is($obj->schemadir, $schemadir, "Schemadir is $schemadir");
}


my $dumper;
diag "Testing the failure";
my $qvr = Shipping::UPS::Tiny::QuantumView::Response->new(response => $testfiles{failure},
                                                          schemadir => $schemadir);
ok(!$qvr->bookmark, "No bookmark found");
ok($qvr->is_failure, "It's a failure");
ok(!$qvr->is_success, "It's not a success");
ok($qvr->error_desc, "Error: " . $qvr->error_desc);
ok(!$qvr->qv_section, "No QV section found");
ok($qvr->response_section, "But response is there");

$dumper = Data::Dumper->new([$qvr->qv_section]);
$dumper->Maxdepth(1);
print $dumper->Dump;


diag "Testing the days";
$qvr = Shipping::UPS::Tiny::QuantumView::Response->new(response => $testfiles{days},
                                                       schemadir => $schemadir);

ok(!$qvr->bookmark, "No bookmark found");
ok(!$qvr->is_failure, "It's not a failure");
ok($qvr->is_success, "It's a success");
ok(!$qvr->error_desc, "Error: " . $qvr->error_desc);
ok(!$qvr->qv_section, "But no QV section found (thanks ups)");
ok($qvr->response_section, "Response is there");

$dumper = Data::Dumper->new([$qvr->qv_section]);
$dumper->Maxdepth(1);
print $dumper->Dump;

diag "Testing unread";
$qvr = Shipping::UPS::Tiny::QuantumView::Response->new(response => $testfiles{unread},
                                                       schemadir => $schemadir);
ok(!$qvr->bookmark, "No bookmark found");
ok(!$qvr->is_failure, "It's not a failure");
ok($qvr->is_success, "It's a success");
ok(!$qvr->error_desc, "No error");
ok($qvr->qv_section, "QV section found");
ok($qvr->response_section, "Response is there");
ok($qvr->qv_subscriber_id, "Got a subscriber id: " . $qvr->qv_subscriber_id);

my @manifests = $qvr->qv_manifests;

ok(@manifests, "Got " . scalar(@manifests) . " manifests");
my $manifest = shift @manifests;

foreach (qw/subscription_number subscription_name subscription_status
           subscription_status_desc file_status_desc file_status
           file_name/) {
    ok($manifest->$_, "Got $_: " . $manifest->$_);
}


my $samplefile = catfile ("t", "QuantumView", "QuantumViewforPackage",
                          "QUANTUMVIEWXML", "Sample Requests and Responses",
                          "QuantumView_Tool_SampleResponse.xml");




if (-f $samplefile) {
    $qvr = Shipping::UPS::Tiny::QuantumView::Response->new(response => $samplefile,
                                                           schemadir => $schemadir);
    ok($qvr->is_success, "is success");
    ok($qvr->qv_subscriber_id, "Got a subscriber id: " . $qvr->qv_subscriber_id);
    ok(!$qvr->is_failure, "No failure");
    ok(!$qvr->error, "No error");
    $dumper = Data::Dumper->new([[$qvr->qv_events]]);
    $dumper->Maxdepth(6);
    # print $dumper->Dump;
}




sub fix_bogus_data {
    my $file = shift;
    my $text = read_file($file);
    $text =~ s{(<Manifest>)\s*(<Shipper>)\s*(<Address>)\s*(<ConsigneeName>(.*?)</ConsigneeName>)}{$1$2<Name>$4</Name>$3}gs;
    $text =~ s{<DeliveryLocation>\s*<Code>.*?</DeliveryLocation>}{}gs;
    $file =~ s/unread\.xml$/unread-good.xml/;
    write_file($file, $text);
    return $file;
}



print Dumper();


