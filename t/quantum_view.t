
use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;

plan tests => 4;

my $conffile = catfile(t => 'conf.yml');

unless (-f $conffile) {
    plan skip_all => "Please copy conf.yml.sample to conf.yml with the right credentials to run the tests";
    exit;
}

my $conf = LoadFile($conffile);

my $ups = Shipping::UPS::Tiny->new(
                                   %{ $conf->{account} }
                                  );

my $qv = $ups->quantum_view;

print Dumper($qv);
ok($qv, "object initialized");
ok($qv->username, "Username present");
ok($qv->account_key, "Key present");
ok($qv->password, "Password present");


