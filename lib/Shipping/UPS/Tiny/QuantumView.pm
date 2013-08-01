package Shipping::UPS::Tiny::QuantumView;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Date::Parse;
use File::Spec;
use XML::Compile::Schema;
use XML::LibXML;
use LWP::UserAgent;
use HTTP::Request;
use POSIX qw/strftime/;
use Shipping::UPS::Tiny::QuantumView::Response;
use Moo;


=head1 NAME

Shipping::UPS::Tiny::QuantumView -- class for QuantumView information

=head1 ACCESSORS

=head2 Credentials

=over 4

=item account_key

The key provided by UPS

=item username

The username

=item password

The password

=item endpoint

By default: https://wwwcie.ups.com/ups.app/xml/QVEvents (testing)

In production, you have to set this to
https://onlinetools.ups.com/ups.app/xml/QVEvents

This is a read-only accessor, so you have to set it in the
constructor (or calling the Tiny module with

  $ups->quantum_view(endpoint => 'https://onlinetools.ups.com/ups.app/xml/QVEvents');

=item schemadir

The directory in which the XML schema files can be found. Mandatory.

=item subscription_name

The named subscription. This is a read-write accessor, so you can set
it after the object has been built.

=back

=cut

has 'account_key' => (is => 'ro',
                      required => 1);

has 'username' => (is => 'ro',
                   required => 1);

has 'password' => (is => 'ro',
                   required => 1);

has endpoint => (is => 'ro',
                 default => sub { return 'https://wwwcie.ups.com/ups.app/xml/QVEvents' });

has schemadir => (is => 'ro',
                  isa => sub {
                      die "$_[0] is not a dir" unless -d $_[0];
                  },
                  required => 1);

has subscription_name => (is => 'rw');

=head1 METHODS

=over 4

=item fetch(begin => "18/dec/2013", end => "22/dec/2012")

The main method. Fetch the data from UPS and return a
L<Shipping::UPS::Tiny::QuantaView::Response> object.

Options (mutually exclusive):

  unread => 1
  days => 1
  begin => "time string"

Option when "begin" is specified:

  end => "time string"

The "time string" can be in any format supported by Date::Parse

The value of C<days> specified the number of previous days for which
we need the data.

The value of C<unread> specified the number or request to make. Given
that we can have a lot of traffic, unread could download a B<lot> of
data. So with the value passed you can set the number of requests
(each being aproximately 250kb).

Default: days => 1 (one day)

=back

=cut

sub fetch {
    my $self = shift;
    die "Unpaired options" if @_ % 2;
    my %args = @_;
    if ((keys %args) > 1) {
        die "mutually exclusive options passed"
          unless ($args{begin} && $args{end});
    }

    if ($args{unread}) {
        return $self->_fetch_unread($args{unread});
    }

    if ($args{begin} && $args{end}) {
        my $starttime = str2time($args{begin});
        my $endtime   = str2time($args{end});
        die "Wrong begin time format!" unless $starttime;
        die "Wrong end time format!" unless $endtime;
        return $self->_fetch_range($starttime, $endtime);
    }

    # fallback
    if (my $days = $args{days} || 1) {
        my $endtime = time();
        my $starttime = $endtime - ($days * 60 * 60 * 24);
        return $self->_fetch_range($starttime, $endtime);
    }

}

sub _fetch_unread {
    my $self = shift;
    return Shipping::UPS::Tiny::QuantumView::Response->new(response => $self->_retrieve);
}

# sub _fetch_unread {
#     my ($self, $num) = @_;
#     die "Wrong num $num!" if $num < 0;
#     my $res = {};
#     while ($num > 0) {
#         $res = $self->_retrieve(bookmark => $res->{bookmark});
#         last unless $res->{bookmark};
#         $num--;
#     }
#     if ($res->{bookmark}) {
#         warn "Not all the data has been fetched!";
#     }
# }
# 

sub _fetch_range {
    my ($self, $beg, $end) = @_;
    my $res = $self->_retrieve(beg => $beg,
                               end => $end);
    return Shipping::UPS::Tiny::QuantumView::Response->new(response => $res);
}

has debug_request => (is => 'rwp',
                      default => sub { return "" });


has ua => (is => 'ro',
           default => sub {
               my $ua = LWP::UserAgent->new;
               $ua->timeout(6);
               return $ua;
           });


sub _retrieve {
    my ($self, %args) = @_;
    my $xml = $self->access_request_xml;
    $xml .= $self->_write_xml_from_schema("QuantumViewRequest",
                                          $self->request_hash(%args));
    my $req = HTTP::Request->new(POST => $self->endpoint);
    $req->content($xml);
    $self->_set_debug_request($xml);
    return $self->ua->request($req);
}

=head2 The request

The request is composed by two concatenated xml docs. The first part
is the access request, which cannot change. The second is the request
itself, which has a few options.

=over 4 

=item access_request_hash

Hashref with key, user, password, to feed the XML compiler.

=item access_request_xml

Returns the XML I<string> and caches it for future invocations.

=cut


sub access_request_hash {
    my $self = shift;
    return {
            AccessLicenseNumber => $self->account_key,
            UserId => $self->username,
            Password => $self->password,
           };
}

has _cache_access_request_xml => (is => 'rw');

sub _write_xml_from_schema {
    my ($self, $schemaname, $hashref) = @_;
    my $schemafile = File::Spec->catfile($self->schemadir,
                                         "$schemaname.xsd");
    die "Missing $schemafile" unless -f $schemafile;
    my $schema = XML::Compile::Schema->new($schemafile);
    my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $writer = $schema->compile(WRITER => $schemaname);
    my $xml = $writer->($doc, $hashref);
    $doc->setDocumentElement($xml);
    return $doc->toString;
}


sub access_request_xml {
    my $self = shift;
    if (my $xml = $self->_cache_access_request_xml) {
        return $xml;
    }
    # cache it
    my $xmlstring = $self->_write_xml_from_schema("AccessRequest",
                                                  $self->access_request_hash);
    $self->_cache_access_request_xml($xmlstring);
    return $xmlstring;
}

sub request_hash {
    my ($self, %args) = @_;

    # basically this could be enough to get all the unread data
    my $qvr = { Request => {
                            RequestAction => 'QVEvents'
                           }
              };

    # but if we have a named subscription, use that
    if (my $subscription_name = $self->subscription_name) {
        $qvr->{SubscriptionRequest}->{Name} = $subscription_name;
    }
    
    # and, if we have args with begin/end, we throw that in too
    if ($args{beg} && $args{end}) {
        $qvr->{SubscriptionRequest}->{DateTimeRange}->{BeginDateTime} =
          _time_to_ups_format($args{beg});
        $qvr->{SubscriptionRequest}->{DateTimeRange}->{EndDateTime} =
          _time_to_ups_format($args{end});
    }
    elsif ($args{beg} || $args{end}) {
        die "missing arguments to pass a range <$args{beg}> <$args{end}>!"
    }

    # and if we have a bookmark, pick that up
    if ($args{bookmark}) {
        $qvr->{Bookmark} = $args{bookmark};
    }
    return $qvr;
}

sub _time_to_ups_format {
    my $time = shift;
    return strftime('%Y%m%d%H%M%S', localtime($time));
}




1;
