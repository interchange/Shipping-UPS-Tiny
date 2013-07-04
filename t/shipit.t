
use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;


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

done_testing;
