use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny::Rates;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;
use MIME::Base64 qw/decode_base64/;

my $conffile = catfile(t => 'rates.yml');

if (-f $conffile) {
    plan tests => 20;
} else {
    plan skip_all => "Please copy conf.yml.sample to rates.yml with the right credentials to run the tests. The 'from' and 'to' fields are ignored";
    exit;
}

my $conf = LoadFile($conffile);

print Dumper($conf->{account});

my $ups = Shipping::UPS::Tiny::Rates->new(%{ $conf->{account} });

for (qw/username password account_key schema_dir/) {
    is $ups->$_, $conf->{account}->{$_}, "$_ ok: " . $ups->$_;
}

$ups->from({
            name => "John Doe",
            address => "Washington road",
            city => "New York",
            postal_code => '10001',
            province => "NY",
            country => "US",
           });

ok($ups->from_address, "From address OK");
print Dumper $ups->from_address;

$ups->to({
          name => 'Big Jim',
          address => 'rue de Fantasy',
          city => 'Paris',
          postal_code =>  '75001',
          country =>  'FR',
         });

ok($ups->to_address, "To address OK");
print Dumper $ups->to_address;
ok($ups->shipper_address, "Shipper address OK");

$ups->set_package({
                   length => 4,
                   width => 4,
                   height => 4,
                   weight => 0.1,
                   cm_kg => 0,
                  });

$ups->request_type('Shop');
# $ups->service('11');

my $rates = $ups->rates;
ok $rates->is_success, "Success!";
ok $rates->alert, "Alert found! " . $rates->alert;
ok !$rates->is_fault, "No fault";
ok $rates->raw_response, "Found raw response";
# print Dumper($rates->_result);
ok $rates->_result, "Found the result";
# print Dumper($rates->_response);
ok $rates->_response, "Found the response";
# print Dumper($rates->raw_response);
my @rates = $rates->list_rates;
ok(scalar(@rates), "found rates");
my $cheaper = $rates[0];
foreach (qw/currency charge name code/) {
    ok ($cheaper->{$_}, "found $_: " . $cheaper->{$_});
}
diag "Testing the error";

$ups->set_package({
                   length => 4,
                   width => 4,
                   height => 4,
                   weight => 0.1,
                   cm_kg => 1,
                  });

$rates = $ups->rates;
# print Dumper($rates->raw_response);
ok($rates->is_fault, "Got fault: " . $rates->is_fault);
ok(!$rates->list_rates, "No rates available");
