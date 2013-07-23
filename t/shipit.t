
use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;
use MIME::Base64 qw/decode_base64/;

plan tests => 26;

my $conffile = catfile(t => 'conf.yml');

unless (-f $conffile) {
    plan skip_all => "Please copy conf.yml.sample to conf.yml with the right credentials to run the tests";
    exit;
}

my $conf = LoadFile($conffile);

my $ups = Shipping::UPS::Tiny->new(
                                   %{ $conf->{account} }
                                  );

for (qw/username password account_key ups_account schema_dir wsdlfile/) {
    is $ups->$_, $conf->{account}->{$_}, "$_ ok";
}

is($ups->endpoint, "https://wwwcie.ups.com/webservices/Ship",
   "endpoint is set to development by default");

ok($ups->soap, "SOAP client exists");

# print Dumper $conf->{from};

$ups->from({
            %{ $conf->{from} }
           });

ok($ups->from_address, "From address OK");
# print Dumper $ups->from_address;

$ups->to({
          %{ $conf->{to} }
         });

ok($ups->to_address, "To address OK");
# print Dumper $ups->to_address;

ok($ups->shipper_address, "Shipper address OK");

# print Dumper($ups->shipper_address);

$ups->set_package({
                   description => "Test package",
                   length => 10,
                   width => 10,
                   height => 10,
                   weight => 0.1,
                  });

is_deeply($ups->service, {
                          Code => '11',
                          Description => 'UPS Standard',
                         }, "service hash ok");

$ups->service('07');

is_deeply($ups->service, {
                          Code => '07',
                          Description => 'Express',
                         }, "service changed ok");

$ups->service('11');


ok($ups->package_props);
diag Dumper($ups->package_props);

# print Dumper($ups->package_props);

$ups->credit_card_info({
                        %{$conf->{from}},
                        number => '4111111111111111',
                        type => '06',
                        sec_code => '123',
                        expire => '122016',
                       });


my $res =  $ups->ship("Test");

ok ($ups->debug_trace->request->content);
# $ups->debug_trace->printRequest;
# $ups->debug_trace->printResponse;

ok($res->is_success, "Success!");
ok(!$res->is_fault, "No fault");
diag $res->is_fault || "OK";


ok(!$res->alert, "No alerts");
ok($res->ship_id, "Got an ID " . $res->ship_id);
ok($res->billing_weight, "Total weight: " . $res->billing_weight);
ok($res->shipment_charges, "Total charging: " . $res->shipment_charges);
ok($res->packages, "Got packages");
my $targetdir = catdir(t => "labels-$$");
diag "Saving labels in $targetdir";
$res->save_labels($targetdir);

foreach my $pack ($res->packages) {
    ok(-f catfile($targetdir, $pack->{label_filename}));
}



$ups->service('01');
$res = $ups->ship("test fault");
ok($res->is_fault);
ok(!$res->is_success);
diag $res->is_fault;
ok(!$res->alert);

