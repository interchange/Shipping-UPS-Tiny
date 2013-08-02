
use strict;
use warnings;
use YAML qw/LoadFile/;
use Shipping::UPS::Tiny;
use File::Spec::Functions;
use Data::Dumper;
use Test::More;
use File::Path qw/mkpath/;

my $conffile = catfile(t => 'conf.yml');

unless (-f $conffile) {
    plan skip_all => "Please copy conf.yml.sample to conf.yml with the right credentials to run the tests";
    exit;
}

my $schema_dir = catdir(qw/t QuantumView QuantumViewforPackage
                           QUANTUMVIEWXML Schemas/);

unless (-d $schema_dir) {
    plan skip_all => "Please get the QuantumView zip and unpack it into the 't' directory if you want to run the tests" ;
    exit;
}



plan tests => 13;



my $conf = LoadFile($conffile);

my $ups = Shipping::UPS::Tiny->new(
                                   %{ $conf->{account} }
                                  );

my $qv = $ups->quantum_view(schemadir => $schema_dir);

print Dumper($qv);
ok($qv, "object initialized");
ok($qv->username, "Username present");
ok($qv->account_key, "Key present");
ok($qv->password, "Password present");
is($qv->endpoint, 'https://wwwcie.ups.com/ups.app/xml/QVEvents',
   "endpoint is correct (wwwcie)");
my $got = $qv->access_request_xml;
diag $qv->access_request_xml;
is ($qv->_cache_access_request_xml, $got, "Cache ok");

$qv->subscription_name("ExceptionandDeliver");
$got = $qv->request_hash(beg => 10, end => 100, bookmark => '1234');

my $expected = {
                'SubscriptionRequest' => {
                                          'DateTimeRange' => {
                                                              'BeginDateTime' => '19700101010010',
                                                              'EndDateTime'   => '19700101010140'
                                                             },
                                          Name => "ExceptionandDeliver",
                                         },
                'Bookmark' => '1234',
                'Request' => {
                              'RequestAction' => 'QVEvents'
                             }
               };

is_deeply($got, $expected, "Request hash is correct");

my $res = $qv->fetch(begin => '2013-07-01',
                     end => '2013-08-01');

ok ($res->parsed_data, "request Ok for range");
ok (!$res->is_success, "Not ok, range is off");
save_lwp_response($res->response, "failure.xml");
print Dumper($res->parsed_data);

$res = $qv->fetch(days => 7);
ok ($res->parsed_data, "request Ok for 7 days");
ok($res->is_success, "Ok, we got something");
save_lwp_response($res->response, "days.xml");
print Dumper($res->parsed_data);

$res = $qv->fetch(unread => 1);
ok( $res->parsed_data);
ok($res->is_success);

save_lwp_response($res->response, "unread.xml");


sub save_lwp_response {
    my ($res, $file) = @_;
    die "Missing arg" unless $file;
    my $dir = catdir(t => 'quantum-data');
    mkdir $dir unless -d $dir;
    my $save_to = catfile ($dir, $file);
    # don't encode it, we use ->content, not ->decoded_content
    open (my $fh, '>', $save_to) or die $!;
    print $fh $res->content;
    close $fh;
}
