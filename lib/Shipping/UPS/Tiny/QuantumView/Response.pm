package Shipping::UPS::Tiny::QuantumView::Response;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Date::Parse;
use File::Spec;
use XML::LibXML::Simple qw/XMLin/;
use POSIX qw/strftime/;
use Scalar::Util qw/blessed/;
use Moo;

=head1 NAME

Shipping::UPS::Tiny::QuantumViewResponse -- class for QuantumView response

=head1 METHODS/ACCESSORS

=head3 response

The response. This can be either a reference to a string or a
HTTP::Response object, or string with a filename with the response
content.

=head3 is_success

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
    my $out;
    foreach my $k(keys %error) {
        $out .= "$k: " . $error{$k} . "\n";
    }
    return $out || "Unparsed error!";
}


1;
