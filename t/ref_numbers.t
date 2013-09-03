
use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny;
use File::Spec;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;
use MIME::Base64 qw/decode_base64/;

my $conffile = catfile(t => 'conf.yml');

if (-f $conffile) {
    plan tests => 8;
}
else {
    plan skip_all => "Please copy conf.yml.sample to conf.yml with the right credentials to run the tests";
    exit;
}

my $conf = LoadFile($conffile);

my $ups = Shipping::UPS::Tiny->new(
                                   %{ $conf->{account} }
                                  );

$ups->from({
            %{ $conf->{from} }
           });

$ups->to({
          %{ $conf->{to} }
         });

my $ref_num = "F322179";
$ups->reference_number("F322179");
is($ref_num, $ups->reference_number);
is($ups->reference_number_type, 'PO');
$ups->set_package({
                   description => "Test package",
                   length => 10,
                   width => 10,
                   height => 10,
                   weight => 0.1,
                  });
my $res =  $ups->ship("Test");
ok($res->is_success, "Success!");
ok(!$res->is_fault, "No fault");
diag $res->is_fault || "OK";
ok($res->ship_id, "Got an ID " . $res->ship_id);
ok($res->billing_weight, "Total billing weight: " . $res->billing_weight);
ok($res->shipment_charges, "Total charging: " . $res->shipment_charges);
my $targetdir = catdir(t => "labels-$$");
diag "Saving labels in " . File::Spec->rel2abs($targetdir);
$res->save_labels($targetdir);

foreach my $pack ($res->packages) {
    ok(-f catfile($targetdir, $pack->{label_filename}));
}

my $response_hash = $res->raw_response;
# don't clutter the output with the base64 things
delete $response_hash->{Body}->{ShipmentResults}->{PackageResults};

diag Dumper($response_hash);
