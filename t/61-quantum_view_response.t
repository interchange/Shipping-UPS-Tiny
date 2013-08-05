
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
    plan tests => 154;
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

diag "Testing the days";
$qvr = Shipping::UPS::Tiny::QuantumView::Response->new(response => $testfiles{days},
                                                       schemadir => $schemadir);

ok(!$qvr->bookmark, "No bookmark found");
ok(!$qvr->is_failure, "It's not a failure");
ok($qvr->is_success, "It's a success");
ok(!$qvr->error_desc, "Error: " . $qvr->error_desc);
ok(!$qvr->qv_section, "But no QV section found (thanks ups)");
ok($qvr->response_section, "Response is there");

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

$dumper = Data::Dumper->new([$qvr->qv_section]);
$dumper->Maxdepth(8);
print $dumper->Dump;

test_manifests(manifests => devserver  => $qvr->qv_manifests);
test_manifests(deliveries => devserver => $qvr->qv_deliveries);
test_manifests(exceptions => devserver => $qvr->qv_exceptions);
test_manifests(origin => testfile => $qvr->qv_origin);

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
    test_manifests(manifests => testfile => $qvr->qv_manifests);
    test_manifests(exceptions => testfile => $qvr->qv_exceptions);
    test_manifests(origin => testfile => $qvr->qv_origin);

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


sub test_manifests {
    my ($type, $name, @manifests) = @_;
    my $prefix = "$type/$name";
    ok(@manifests, "Got " . scalar(@manifests) . " $prefix");

    # test only the first one
    my $manifest = shift @manifests;

    foreach (qw/subscription_number subscription_name subscription_status
                subscription_status_desc file_status_desc file_status
                file_name/) {
        ok($manifest->$_, "$prefix: Got $_: " . $manifest->$_);
    }
    ok $manifest->data, "$prefix: Found data";

    if ($type eq 'deliveries') {
        is($manifest->source, "delivery");
        ok($manifest->tracking_number,
           "$prefix Tracking number: " . $manifest->tracking_number);
        ok($manifest->delivery_datetime,
           "$prefix delivery dt: " . $manifest->delivery_datetime);
        ok(defined $manifest->activity_location,
           "$prefix location: " . $manifest->activity_location);
    }

    if ($type eq 'exceptions') {
        print Dumper($manifest->data);
        is($manifest->source, "exception");
        ok($manifest->tracking_number,
           "$prefix Tracking number: " . $manifest->tracking_number);
        ok($manifest->exception_datetime,
           "$prefix Exception Datetime: " . $manifest->exception_datetime);
        ok(defined $manifest->activity_location,
           "$prefix location: " . $manifest->activity_location);
        ok(defined $manifest->description, "$prefix desc: " . $manifest->description);
        ok(defined $manifest->resolution, "$prefix resolution: " . $manifest->resolution);
        ok(defined $manifest->rescheduled_date,
           "$prefix reschedule: " . $manifest->rescheduled_date);
    }

    if ($type eq 'origin') {
        print Dumper($manifest->data);
    }

    if ($type eq 'manifests') {
        ok($manifest->shipper,
           "$prefix: Found shipper: " . Dumper($manifest->shipper));
        ok($manifest->ship_to,
           "$prefix: Found ship to: " . Dumper($manifest->ship_to));

        # please note that the test files are missing a desc and that
        # the code is illegal, as per doc...
        ok($manifest->service_code,
           "$prefix: Found service code: " . $manifest->service_code);

        ok($manifest->pickup_date,
           "$prefix: Found pickup date: " . $manifest->pickup_date);

        # of course the test things don't have the delivery time
        # ok($manifest->scheduled_delivery_time,
        # "$prefix: Found scheduled delivery time"
        my @packages = $manifest->packages;
        foreach my $pack (@packages) {
            foreach my $accessor (qw/subscription_number
                                     subscription_name subscription_status
                                     subscription_status_desc file_status_desc file_name
                                     service_code pickup_date
                                     tracking_number
                                     reference_numbers
                                     activities_datetime
                                     scheduled_delivery_date
                                     source/) {
                ok((defined $pack->$accessor),
                   "$prefix package: $accessor: " . join(" ", $pack->$accessor));
            }
            ok($pack->data, "Found the package data: " . Dumper($pack->data));
        }


        if ($name eq 'testfile') {
            ok(scalar($manifest->reference_numbers),
               "$prefix: Found reference numbers " .
               Dumper($manifest->reference_numbers));
        }
    }
}
