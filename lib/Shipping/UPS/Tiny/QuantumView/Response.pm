package Shipping::UPS::Tiny::QuantumView::Response;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Date::Parse;
use File::Spec;
use XML::LibXML::Simple;
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
                );

sub _trigger_response  {
    my ($self, $value) = @_;
    # todo: handle undef values, undef content, etc. etc.

    if (blessed($value)) {
        # it's an object
        $self->_set_parsed_data($self->parser->XMLin($value->content));
    }
    elsif (ref($value) eq 'SCALAR') {
        $self->_set_parsed_data($self->parser->XMLin($$value));
    }
    else {
        # Simple accepts filenames
        $self->_set_parsed_data($self->parser->XMLin($value));
    }
    unless ($self->parsed_data) {
        # we screwed up, we could fill this up with an error.
        $self->_set_parsed_data({});
    }
}

has parser => (is => 'ro',
               default => sub {
                   return XML::LibXML::Simple->new;
               });

has parsed_data => (is => 'rwp');

sub response_section {
    my $self = shift;
    return { %{$self->parsed_data->{Response}} };
}

sub is_success {
    my $self = shift;
    return $self->response_section->{ResponseStatusCode};
}

1;
