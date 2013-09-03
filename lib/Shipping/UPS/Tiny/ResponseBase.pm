package Shipping::UPS::Tiny::ResponseBase;

use 5.010000;
use strict;
use warnings FATAL => 'all';

use Moo;

use Data::Dumper;

=head1 NAME

Shipping::UPS::Tiny::ResponseBase -- base class for UPS API responses

=head1 DESCRIPTION

This class provides some shared methods for
L<Shipping::UPS::Tiny::ShipmentResponse> and
L<Shipping::UPS::Tiny::RatesResponse>

=head1 ACCESSOR/METHODS

=over 4

=item raw_response

The raw hashref with the parsed response.

=item is_success

Return true if the request reported a success.

=item is_fault

If true, the code and descriptions of the fault(s) are returned as a
single string, meant to be displayed to the final user.

=item alert

Return the string with the alert(s), or the empty string.

=cut

has raw_response => (is => 'ro',
                     required => 1,
                     trigger => 1,
                     isa => sub {
                         die "the response must be an hashref"
                           unless ref($_[0]) eq 'HASH';
                     });


has _response => (is => 'rw');
has _fault => (is => 'rw');
has _result => (is => 'rw');

sub _trigger_raw_response {
    # set the various hashrefs
    my $self = shift;
    my $raw = $self->raw_response;
    # warn Dumper($raw);
    # it's not clear when the root is "Body" or the keys sit on the
    # the root.

    if ((exists $raw->{Fault}) or
        (exists $raw->{Body} and exists $raw->{Body}->{Fault}) or
        (exists $raw->{ShippingError}) or
        (exists $raw->{RateError})) {
        $self->_store_error_details;
    }

    if (exists $raw->{Body} and exists $raw->{Body}->{Response}) {
        $self->_response($raw->{Body}->{Response});
    }
    elsif (exists $raw->{Response}) {
        $self->_response($raw->{Response});
    }

    foreach my $k (qw/ShipmentResults RatedShipment/) {
        if (exists $raw->{Body} and exists $raw->{Body}->{$k}) {
            $self->_result($raw->{Body}->{$k});
        }
        elsif (exists $raw->{$k}) {
            $self->_result($raw->{$k});
        }
    }
}

sub is_fault {
    my $self = shift;
    my $desc = "";
    if (my $faults = $self->_fault) {
        foreach my $f (@$faults) {
            $desc .= $f->{PrimaryErrorCode}->{Description} . " (" .
              $f->{PrimaryErrorCode}->{Code} . ")\n";
        }
    }
    return $desc;
}

sub alert {
    my $self = shift;
    my $out = "";
    return "" unless $self->_response;
    if (exists $self->_response->{Alert}) {
        my $alert = $self->_response->{Alert};
        if (ref($alert) eq 'ARRAY') {
            foreach my $al (@$alert) {
                $out .= $al->{Description} . "( " . $al->{Code} . ")\n";
            }
        }
        elsif (ref($alert) eq 'HASH') {
            $out = $alert->{Description} . "( " . $alert->{Code} . ")\n";
        }
    }
    return $out;
}


sub is_success {
    my $self = shift;
    if ($self->_response) {
        if ($self->_response->{ResponseStatus}->{Code} eq '1') {
            return 1;
        }
    }
    return 0;
}

sub _store_error_details {
    my $self = shift;
    my $raw = $self->raw_response;
    my $error;

    if (exists $raw->{ShipmentError}) {
        $error = $raw->{ShipmentError}->{ErrorDetail};
    }
    elsif (exists $raw->{RateError}) {
        $error = $raw->{RateError}->{ErrorDetail};
    }

    # the following two cases used to work, but not anymore, so we
    # have to catch it before or die.
    elsif (exists $raw->{Fault}->{detail}->{Errors} and
        exists $raw->{Fault}->{detail}->{Errors}->{ErrorDetail}) {
        $error = $raw->{Fault}->{details}->{Errors}->{ErrorDetail};
    }
    elsif (exists $raw->{Body} and
           exists $raw->{Body}->{Fault} and
           exists $raw->{Body}->{Fault}->{detail} and
           exists $raw->{Body}->{Fault}->{detail}->{Errors} and
           exists $raw->{Body}->{Fault}->{detail}->{Errors}->{ErrorDetail}) {
        $error = $raw->{Body}->{Fault}->{detail}->{Errors}->{ErrorDetail};
    }
    unless ($error) {
        die "Unable to handle " . Dumper($raw);
    }
    $self->_fault($error);
}




=back

=cut

1;
