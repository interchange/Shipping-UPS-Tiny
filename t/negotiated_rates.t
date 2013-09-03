
use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny;
use File::Spec;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;
use MIME::Base64 qw/decode_base64/;

plan tests => 11;

my $conffile = catfile(t => 'conf.yml');

unless (-f $conffile) {
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
$ups->reference_number($ref_num);
$ups->address_validation(0);
$ups->negotiated_rates(1);

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

ok((index($ups->debug_trace->request->content,
         '</ship:NegotiatedRatesIndicator></ship:ShipmentRatingOptions>') >= 0), "indicator found") ;

diag Dumper();


ok(exists $ups->debug_hash_request->{Shipment}->{ShipmentRatingOptions}->{NegotiatedRatesIndicator});

if (my $alert = $res->alert) {
    diag "$alert";
}


ok($res->ship_id, "Got an ID " . $res->ship_id);
ok($res->billing_weight, "Total weight: " . $res->billing_weight);
ok($res->billing_weight_unit, "Weight unit: " . $res->billing_weight_unit);
ok($res->billing_weight_in_grams, "In grams: " . $res->billing_weight_in_grams);
ok($res->shipment_charges, "Total charging: " . $res->shipment_charges);
ok($res->shipment_charges_currency,
   "Currency of the shipment fee: " . $res->shipment_charges_currency);
ok($res->packages, "Got packages");


diag ($res->is_fault || "No fault");
