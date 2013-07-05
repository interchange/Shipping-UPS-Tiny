
use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;
use MIME::Base64 qw/decode_base64/;

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

print Dumper $conf->{from};

$ups->from({
            %{ $conf->{from} }
           });

ok($ups->from_address, "From address OK");
print Dumper $ups->from_address;

$ups->to({
          %{ $conf->{to} }
         });

ok($ups->to_address, "To address OK");
print Dumper $ups->to_address;

ok($ups->shipper_address, "Shipper address OK");

print Dumper($ups->shipper_address);

$ups->set_package({
                   description => "Test package",
                   length => 1,
                   width => 2,
                   height => 3,
                   weight => 0.2,
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


ok($ups->package_props);

print Dumper($ups->package_props);

$ups->credit_card_info({
                        %{$conf->{from}},
                        number => '4111111111111111',
                        type => '06',
                        sec_code => '123',
                        expire => '122016',
                       });

my ($res, $trace) =  $ups->ship("Test");

# brilliant! a HTML page in base 64!
my $html = $res->{Body}->{ShipmentResults}->{PackageResults}->[0]->{ShippingLabel}->{HTMLImage};
my $label = delete $res->{Body}->{ShipmentResults}->{PackageResults}->[0]->{ShippingLabel}->{GraphicImage};
my $track = $res->{Body}->{ShipmentResults}->{PackageResults}->[0]->{TrackingNumber};

ok($html);
ok($label);

my $label_html_file = catfile(t => "label$track.html");
my $label_graphics_file = catfile(t => "label$track.gif");

for ($label_graphics_file, $label_html_file) {
    if (-e $_) {
        unlink $_ or die "Cannot unlink $_ $!";
    }
}

open (my $fh, ">", $label_html_file) or die "Cannot open $label_html_file $!";
print $fh decode_base64($html);
close $fh;

open (my $fhx, ">", $label_graphics_file) or die "Cannot open $label_graphics_file $!";
print $fhx decode_base64($label);
close $fhx;




print Dumper($res);







done_testing;
