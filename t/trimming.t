use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;

my $conffile = catfile(t => 'conf.yml');

if (-f $conffile) {
    plan tests => 3;
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
          company => 'very very very veryvery very very veryvery very very veryvery very very very long name',
          name => 'very very very veryvery very very veryvery very very veryvery very very very long name',
          address => 'Loooooooooooooooooooooooooooooooooooooooooooooo Karl-Kellner-Str. 105J',
          postal_code => '30853',
          country => 'DE',
          city => 'Looooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong city',
          phone => '12341234',
         });


my $addr = $ups->to_address;

diag Dumper($addr);

$ups->set_package({
                   description => "Test package",
                   length => 10,
                   width => 10,
                   height => 10,
                   weight => 0.1,
                  });

my $res =  $ups->ship("Test");

ok($res);
ok($res->is_success);
diag "Got fault " . $res->is_fault if $res->is_fault;
my $targetdir = catdir(t => "labels-$$");
diag "Saving labels in $targetdir";
$res->save_labels($targetdir);
ok($res->shipment_charges, "Total charging: " . $res->shipment_charges);





