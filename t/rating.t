use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny::Rates;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;
use MIME::Base64 qw/decode_base64/;

plan tests => 1;

my $conffile = catfile(t => 'rates.yml');

unless (-f $conffile) {
    plan skip_all => "Please copy conf.yml.sample to rates.yml with the right credentials to run the tests";
    exit;
}

my $conf = LoadFile($conffile);

print Dumper($conf->{account});

my $ups = Shipping::UPS::Tiny::Rates->new(%{ $conf->{account} });

for (qw/username password account_key schema_dir/) {
    is $ups->$_, $conf->{account}->{$_}, "$_ ok: " . $ups->$_;
}

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

$ups->set_package({
                   description => "Test package",
                   length => 10,
                   width => 10,
                   height => 10,
                   weight => 0.1,
                  });

