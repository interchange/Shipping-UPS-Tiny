package Shipping::UPS::Tiny::ShipmentResponse;

use 5.010001;
use strict;
use warnings FATAL => 'all';
use Moo;
use Data::Dumper;


=head1 NAME

Shipping::UPS::Tiny::ShipmentResponse -- response class for Shipment requests

=head1 ACCESSORS/METHODS

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

=back

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

sub _trigger_raw_response {
    # set the various hashrefs
    my $self = shift;
    my $raw = $self->raw_response;
    if (exists $raw->{Fault}) {
        $self->_fault($raw->{Fault});
    }
    elsif (exists $raw->{Body}->{Fault}) {
        $self->_fault($raw->{Body}->{Fault})
    }

    if (exists $raw->{Body}->{Response}) {
        $self->_response($raw->{Body}->{Response});
    }
    elsif (exists $raw->{Response}) {
        $self->_response($raw->{Response});
    }
}



sub is_fault {
    my $self = shift;
    my $desc = "";
    if (my $fault = $self->_fault) {
        if (exists $fault->{detail}->{Errors}->{ErrorDetail}) {
            my $details = $fault->{detail}->{Errors}->{ErrorDetail};
            foreach my $f (@$details) {
                $desc .= $f->{PrimaryErrorCode}->{Description} . " (" .
                  $f->{PrimaryErrorCode}->{Code} . ")\n";
            }
        }
        else {
            die "Cannot handle: " . Dumper($self->raw_response);
        }
    }
    return $desc;
}

sub alert {
    my $self = shift;
    my $alert = "";
    return "" unless $self->_response;
    if (exists $self->_response->{Alert}) {
        my $alert = $self->_response->{Alert};
        if (ref($alert) eq 'ARRAY') {
            foreach my $al (@$alert) {
                $alert .= $alert->{Description} . "( " . $alert->{Code} . ")\n";
            }
        }
        elsif (ref($alert) eq 'HASH') {
            $alert = $alert->{Description} . "( " . $alert->{Code} . ")\n";
        }
    }
    return $alert;
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


1;
