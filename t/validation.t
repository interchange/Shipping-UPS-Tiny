
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
    plan tests => 6;
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
          company =>  'LinuXia',
          name =>  'Stefan',
          address =>  'XXXX',
          city =>  'blablabl',
          postal_code =>  '12345',
          country =>  'DE',
          phone =>  '12341234',
         });

my $ref_num = "F322179";
$ups->reference_number($ref_num);

$ups->address_validation(0);

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
is($ups->debug_hash_request->{Request}->{RequestOption}, 'nonvalidate');

# diag Dumper($ups->debug_hash_request);

$ups = Shipping::UPS::Tiny->new(
                                   %{ $conf->{account} }
                                  );

$ups->from({
            %{ $conf->{from} }
           });

$ups->to({
          company =>  'LinuXia',
          name =>  'Stefan',
          address =>  'XXXX',
          city =>  'blablabl',
          postal_code =>  '123',
          country =>  'DE',
          phone =>  '12341234',
         });

$ups->address_validation(1);

$ups->set_package({
                   description => "Test package",
                   length => 10,
                   width => 10,
                   height => 10,
                   weight => 0.1,
                  });
$res =  $ups->ship("Test");
is($ups->debug_hash_request->{Request}->{RequestOption}, 'validate');
ok(!$res->is_success, "No success!");
ok($res->is_fault, "Fault: " . $res->is_fault);
# diag Dumper($ups->debug_hash_request);
# diag Dumper($ups->debug_trace);


