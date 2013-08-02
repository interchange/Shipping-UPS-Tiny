package Shipping::UPS::Tiny::QuantumView::Response;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Date::Parse;
use File::Spec;
use XML::Compile::Schema;
use File::Spec;
use POSIX qw/strftime/;
use Scalar::Util qw/blessed/;
use Data::Dumper;
use Shipping::UPS::Tiny::QuantumView::Manifest;
use Shipping::UPS::Tiny::QuantumView::Delivery;
use Shipping::UPS::Tiny::QuantumView::Exception;
use Moo;

=head1 NAME

Shipping::UPS::Tiny::QuantumViewResponse -- class for QuantumView response

=head1 METHODS/ACCESSORS

=head3 response

The response. This can be either a reference to a string or a
HTTP::Response object, or string with a filename with the response
content. It B<must> be set in the constructor.

=cut

has schemadir => (is => 'ro',
                  required => 1,
                  isa => sub {
                      die "$_[0] is not a dir" unless -d $_[0];
                  });

has response => (is => 'ro',
                 trigger => 1,
                 required => 1);

sub parser {
    my $self = shift;
    # we don't need to cache this, as every time we parse the xml just once.
    my @schemas;
    # load the definitions
    foreach my $sch ("Error1.1.xsd", "common.xsd", "QuantumViewResponse.xsd") {
        push @schemas, File::Spec->catfile($self->schemadir, $sch);
    }
    my $schema = XML::Compile::Schema->new(\@schemas);
    return $schema->compile(READER => 'QuantumViewResponse');
}


sub _trigger_response  {
}


=head3 error

The error as set by the I<parser>. Mostly internal.

=head3 parsed_data

The raw parsed XML document as Perl data.

=head3 response_section

The "QuantumViewResponse/Response" xpath of the response. Contains
metadata for error handling and asserting the success.

=head3 is_success

Returns true if there is a success. 

=head3 is_failure

Returns true if there is a failure.

=head3 error_desc

Returns a string that flattens the data found in the Error stanza of
the Response.

=cut

has error => (is => 'rw',
              default => sub { return "" });

has _parsed_data_cache => (is => 'rw');

sub parsed_data {
    my $self = shift;
    if ($self->_parsed_data_cache) {
        return $self->_parsed_data_cache;
    }
    # no cache? ok, do the parsing
    my $value = $self->response;
    if (blessed($value)) {
        # it's an LWP object;
        if ($value->is_success)  {
            my $parsed;
            eval {
                $parsed = $self->parser->($value->content);
            };
            if ($@) {
                $self->error($@);
            }
            elsif (!$parsed) {
                $self->error("the parsed ref to a scalar returned nothing");
            }
            else {
                $self->_parsed_data_cache($parsed);
            }
        }
        else {
            $self->error($value->status_line);
        }
    }
    else {
        my $body;
        if (ref($value) eq 'SCALAR') {
            $body = $$value;
        }
        else {
            $body = $value;
        }
        # we got a reference to the xml body
        my $parsed;
        eval {
            $parsed = $self->parser->($body);
        };
        if ($@) {
            $self->error($@);
        }
        elsif (!$parsed) {
            $self->error("the parsed ref to a scalar returned nothing");
        }
        else {
            $self->_parsed_data_cache($parsed);
        }
    }
    unless ($self->_parsed_data_cache) {
        # we screwed up, so we populate the data with an equivalent fake response
        $self->_parsed_data_cache({
                                   Response => {
                                                ResponseStatusCode => 0,
                                                ResponseStatusDescription => 'Failure',
                                                Error => [
                                                          {
                                                           'ErrorDescription' => $self->error,
                                                           'ErrorCode' => '999999',
                                                           'ErrorSeverity' => 'Hard'
                                                          }
                                                         ]
                                               }
                                  });
    }
}




sub response_section {
    my $self = shift;
    return { %{$self->parsed_data->{Response}} };
}

sub is_success {
    my $self = shift;
    # response status code is guaranteed to be present
    return $self->response_section->{ResponseStatusCode};
}

sub is_failure {
    my $self = shift;
    if ($self->is_success) {
        return;
    }
    return $self->response_section->{ResponseStatusDescription};
}

sub error_desc {
    my $self = shift;
    my $data = $self->response_section;
    return "" unless exists $data->{Error};
    # flatten the hash. except that the compiler returns us an array,
    # because the definition says it's unbound, while the doc says
    # it's just one. So act accordly.
    my $error_ref = $data->{Error};
    print Dumper($error_ref);
    my @errors = @{$data->{Error}};
    my @out;
    foreach my $error (@errors) {
        foreach my $k (keys %$error) {
            my $error_detail;
            if (ref($error->{$k})) {
                $error_detail = Dumper($error->{$k});
            }
            else {
                $error_detail = $error->{$k};
            }
            push @out, "$k: " . ($error_detail || "");
        }
    }
    return join(" ", @out) || "Unparsed error!";
}



=head3 qv_section

Returns the main hashref with the actual QV data. The data are splits
in numbered events, which are accessible via the C<qv_events> accessor.

In turn, each event has one or more "subscription files". In there we
can find the actual data.

$VAR1 = {
    'SubscriptionEvents' => [
        {
            'Number' => '21B6D76A8B32564B',
            'SubscriptionFile' => [
                {
                    'StatusType' => {
                        'Code' => 'U',
                        'Description' => 'Show Unread'
                       },
                    'FileName' => '020208_133243003',
                    'cho_Manifest' => [
                        {
                            'Origin' => [
                                'HASH(0x3970be8)'
                               ]
                           },
                        {
                            'Delivery' => [
                                'HASH(0x39ef1e0)',
                                'HASH(0x35e75b8)',
                                'HASH(0x3987698)'
                               ]
                           }
                       ]
                   },
                {
                    'StatusType' => {
                        'Code' => 'U',
                        'Description' => 'Show Unread'
                       },
                    'FileName' => '020211_133241001',
                    'cho_Manifest' => [
                        {
                            'Manifest' => [
                                'HASH(0x356ccd0)',
                                'HASH(0x3987470)',
                                'HASH(0x358ac78)'
                               ]
                           }
                       ]
                   }
               ],
            'SubscriptionStatus' => {
                'Code' => 'A',
                'Description' => 'Active'
               },
            'Name' => 'IVS'
           },
        {
            'Number' => '21B6D76A8B32564C',
            'SubscriptionFile' => [
                {
                    'StatusType' => {
                        'Code' => 'U',
                        'Description' => 'Show Unread'
                       },
                    'FileName' => '020208_133242002',
                    'cho_Manifest' => [
                        {
                            'Manifest' => [
                                'HASH(0x39dd370)',
                                'HASH(0x397acd0)',
                                'HASH(0x341c9d0)',
                                'HASH(0x348e578)'
                               ]
                           },
                        {
                            'Exception' => [
                                'HASH(0x35a9258)'
                               ]
                           },
                        {
                            'Delivery' => [
                                'HASH(0x3987b90)',
                                'HASH(0x3a04248)'
                               ]
                           }
                       ]
                   },
                {
                    'StatusType' => {
                        'Code' => 'U',
                        'Description' => 'Show Unread'
                       },
                    'FileName' => '020208_133244004',
                    'cho_Manifest' => [
                        {
                            'Origin' => [
                                'HASH(0x3653c68)'
                               ]
                           },
                        {
                            'Delivery' => [
                                'HASH(0x3945818)',
                                'HASH(0x3a81c98)',
                                'HASH(0x3a81f80)'
                               ]
                           }
                       ]
                   }
               ],
            'SubscriptionStatus' => {
                'Code' => 'A',
                'Description' => 'Active'
               },
            'Name' => 'OVS'
           }
       ],
    'SubscriberID' => 'XXXXXX'
   };

=cut

sub qv_subscriber_id {
    my $self = shift;
    if (my $data = $self->qv_section) {
        if (exists $data->{SubscriberID} and defined $data->{SubscriberID}) {
            return $data->{SubscriberID};
        }
    }
    return "";
}


sub qv_section {
    my $self = shift;
    my $data = $self->parsed_data;
    if (exists $data->{QuantumViewEvents}) {
        return $data->{QuantumViewEvents};
    }
    else {
        return;
    }
}

=head3 qv_events

The event that a user receives echoed Subscriber ID and information
for subscription event, which is a subset of Tracking information
specific to either packages coming or packages going, after
subscription request is made, if the user requests for XML format.

Returns a list with the events.

Each event has the following structure:

   { 
     'Number' => '45BD09FCCEEA27BA',
     'SubscriptionFile' => [
                           { 
                             'StatusType' => 'HASH(0x2951b10)',
                             'FileName' => '070824_141035001',
                             'cho_Manifest' => 'ARRAY(0x251c0d8)'
                           },
                           { 
                             'StatusType' => 'HASH(0x293f058)',
                             'FileName' => '070824_143048001',
                             'cho_Manifest' => 'ARRAY(0x29253f8)'
                           },
                           { 
                             'StatusType' => 'HASH(0x25cba00)',
                             'FileName' => '070827_133055001',
                             'cho_Manifest' => 'ARRAY(0x294e810)'
                           }
                         ],
     'SubscriptionStatus' => {
                             'Code' => 'A',
                             'Description' => 'Active'
                           },
     'Name' => 'OutboundFull'
   }

Name, number, status 


=cut

sub qv_events {
    my $self = shift;
    my $qv = $self->qv_section;
    if ($qv and exists $qv->{SubscriptionEvents}) {
        die "The events are not an arrayref" unless ref($qv->{SubscriptionEvents}) eq 'ARRAY';
        return @{$qv->{SubscriptionEvents}};
    }
    else {
        return;
    }
}

=head3 qv_manifests

Returns a list of B<all> the manifests from all the events and files.

A manifest represents all data that is relevant for the shipment, such
as origin, destination, shipper, payment method etc.

Each manifest is a Shipping::UPS::Tiny::QuantumView::Manifest object,
and holds the coordinates of file/subscription.

=cut

sub qv_exceptions {
    my $self = shift;
    return $self->_get_deep_data('Exception');
}

sub qv_manifests {
    my $self = shift;
    return $self->_get_deep_data('Manifest');
}

sub qv_deliveries {
    my $self = shift;
    return $self->_get_deep_data('Delivery');
}


sub _get_deep_data {
    my $self = shift;
    my $target = shift;
    return unless $target;
    my @events = $self->qv_events;
    my @manifests;
    foreach my $event (@events) {
        # these are mandatory fields, reading the doc
        my %sub_details = (
                           subscription_number => $event->{Number},
                           subscription_name => $event->{Name},
                           subscription_status => $event->{SubscriptionStatus}->{Code},
                           # not mandatory, but hey...
                           subscription_status_desc => $event->{SubscriptionStatus}->{Description} || "",
                           );

        # now scan the files
        if (my $files = $event->{SubscriptionFile}) {
            foreach my $file (@$files) {
                my %file_details = (
                                    # mandatory fields, p.43 of the doc
                                    file_status_desc => $file->{StatusType}->{Description},
                                    file_status => $file->{StatusType}->{Code},
                                    file_name => $file->{FileName},
                                   );

                # now finally reach the data, hoping that we get the right key.
                my $blocks = $file->{cho_Manifest};
                unless ($blocks) {
                    die "couldn't find the cho_Manifest" . Dumper($file);
                };
                # well, we're not really there yet
                foreach my $block (@$blocks) {
                    if (exists $block->{$target}) {
                        foreach my $manifest (@{$block->{$target}}) {
                            # reached
                            my $class = "Shipping::UPS::Tiny::QuantumView::$target";
                            push @manifests, $class->new(data => $manifest,
                                                         %file_details,
                                                         %sub_details);
                        }
                    }
                }
            }
        }
    }
    return @manifests;
}

=head3 bookmark

Bookmarks the file for next retrieval, It is a base64Encoded String.
It contains the combination of SubscriberID + SubscriptionName + File
Name if the request is for all data. It contains SubscriberID if the
request is for unread data. When a response comes back with a bookmark
it indicates that there is more data. To fetch the remaining data, the
requester should come back with the bookmark added to the original
request.

Sadly enough, the testing endpoint doesn't return any bookmark, so
this is pretty much untested, but it should work.

When you have a bookmark, to get the rest of the data you need to
reissue the request passing the resulting string to the QV fetching.

TODO: Tweak the QV module to handle the bookmarks gracefully.

=cut


sub bookmark {
    my $self = shift;
    my $data = $self->parsed_data;
    if ((exists $data->{Bookmark}) and $data->{Bookmark}) {
        return $data->{Bookmark};
    }
    else {
        return;
    }
}


1;
