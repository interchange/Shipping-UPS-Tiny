package Shipping::UPS::Tiny::QuantumView::Response;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Date::Parse;
use File::Spec;
use XML::LibXML::Simple qw/XMLin/;
use POSIX qw/strftime/;
use Scalar::Util qw/blessed/;
use Data::Dumper;
use Moo;

=head1 NAME

Shipping::UPS::Tiny::QuantumViewResponse -- class for QuantumView response

=head1 METHODS/ACCESSORS

=head3 response

The response. This can be either a reference to a string or a
HTTP::Response object, or string with a filename with the response
content. It B<must> be set in the constructor.

=cut

has response => (is => 'ro',
                 trigger => 1,
                 required => 1);

sub _trigger_response  {
    my ($self, $value) = @_;
    # todo: handle undef values, undef content, etc. etc.

    if (blessed($value)) {
        # it's an LWP object;
        if ($value->is_success)  {
            my $parsed;
            eval {
                $parsed = XMLin($value->content);
            };
            if ($@) {
                $self->error($@);
            }
            elsif (!$parsed) {
                $self->error("the parsed ref to a scalar returned nothing");
            }
            else {
                $self->_set_parsed_data($parsed);
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
            $parsed = XMLin($body);
        };
        if ($@) {
            $self->error($@);
        }
        elsif (!$parsed) {
            $self->error("the parsed ref to a scalar returned nothing");
        }
        else {
            $self->_set_parsed_data($parsed);
        }
    }
    unless ($self->parsed_data) {
        # we screwed up, so we populate the data with an equivalent fake response
        $self->_set_parsed_data({
                                 Response => {
                                              ResponseStatusCode => 0,
                                              ResponseStatusDescription => 'Failure',
                                              Error => {
                                                        'ErrorDescription' => $self->error,
                                                        'ErrorCode' => '999999',
                                                        'ErrorSeverity' => 'Hard'
                                                       }
                                             }
                                });
    }
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

has parsed_data => (is => 'rwp');

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
    # flatten the hash.
    my %error = %{$data->{Error}};
    my @out;
    foreach my $k(keys %error) {
        my $error_detail;
        if (ref($error{$k})) {
            $error_detail = Dumper($error{$k});
        }
        else {
            $error_detail = $error{$k};
        }
        push @out, "$k: " . ($error_detail || "");
    }
    return join(" ", @out) || "Unparsed error!";
}



=head3 qv_section

Returns the main hashref with the actual QV data.

=cut


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
