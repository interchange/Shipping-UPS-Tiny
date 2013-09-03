use strict;
use warnings;
use Test::More;
use Shipping::UPS::Tiny::Service;

plan tests => 56;

my $service = Shipping::UPS::Tiny::Service->new(service_code => 11);

is $service->service_name, 'UPS Standard', "11 ok";

for my $code (qw/01 02 03 07 08 11 12 13 14 54 59 65 82 83 84 85 86 96/) {
    $service = Shipping::UPS::Tiny::Service->new(service_code => $code);
    ok($service->service_name, "Found $code => " . $service->service_name);
    is($service->as_hash->{Code}, $code, "found code $code");
    is($service->as_hash->{Description}, $service->service_name, "found desc");
}

eval {
    $service = Shipping::UPS::Tiny::Service->new(service_code => 99);
};

ok $@, "Invalid codes generates a crash";
