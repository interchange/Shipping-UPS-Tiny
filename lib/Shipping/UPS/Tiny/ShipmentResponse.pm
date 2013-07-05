package Shipping::UPS::Tiny::ShipmentResponse;

use 5.010001;
use strict;
use warnings FATAL => 'all';
use Moo;
use Data::Dumper;
use File::Spec;
use MIME::Base64 qw/decode_base64/;
use File::Path qw/make_path/;

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

    # it's not clear when the root is "Body" or the keys sit on the
    # the root.

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

    if (exists $raw->{Body}->{ShipmentResults}) {
        $self->_result($raw->{Body}->{ShipmentResults});
    }
    elsif (exists $raw->{ShipmentResults}) {
        $self->_result($raw->{ShipmentResults});
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

=item ship_id

The shipment identification number.

=cut

sub ship_id {
    my $self = shift;
    return "" unless $self->is_success;
    return $self->_result->{ShipmentIdentificationNumber} || "";
}

=item billing_weight

The billing weight, as a string (with units of measurement), to be
displayed.

=cut

sub billing_weight {
    my $self = shift;
    return "" unless $self->is_success;

    die "Unhandled exception with billing weight"
      unless $self->_result->{BillingWeight}->{Weight};

    return $self->_result->{BillingWeight}->{Weight} . " " .
      $self->_result->{BillingWeight}->{UnitOfMeasurement}->{Code};
}

=item shipment_charges

The total charge, as a string with total and currency, to be displayed.

=cut

sub shipment_charges {
    my $self = shift;
    return "" unless $self->is_success;

    die "Missing charges" unless $self->_result->{ShipmentCharges};
    return $self->_result->{ShipmentCharges}->{TotalCharges}->{MonetaryValue} . " " .
      $self->_result->{ShipmentCharges}->{TotalCharges}->{CurrencyCode};
}

=item shipment_charges_details

The details of the charges, as a hashref, taken verbatim from the
response.


=cut

sub shipment_charges_details {
    my $self = shift;
    return "" unless $self->is_success;
    return $self->_result->{ShipmentCharges};
}

=item packages

Returns (if success) the list of packages as a list of hashrefs, each
with the following keys:

    tracking_number # the tracking number
    html # the HTML in base64
    label # the image in  base64 
    ext  # extension

=cut

sub packages {
    my $self = shift;
    return unless $self->is_success;
    my $results = $self->_result;
    my @packs;
    if ($results->{PackageResults}) {
        foreach my $pack (@{$results->{PackageResults}}) {
            my $pack_info = {
                             tracking_number => $pack->{TrackingNumber},
                             html => $pack->{ShippingLabel}->{HTMLImage},
                             label =>  $pack->{ShippingLabel}->{GraphicImage},
                             ext => lc($pack->{ShippingLabel}->{ImageFormat}->{Code}),
                            };
            # check
            foreach my $k (keys %$pack_info) {
                die "Missing expected key $k" unless $pack_info->{$k};
            }
            # and push
            push @packs, $pack_info;
        }
    }
    return @packs;
}

=item save_labels($where)

Save the labels of the packages in the target directory $where.

The naming convention (proposed by the HTML of the response) is the
following: label<tracking_number>.<ext>

The directory is created if does not exist.

The method will refuse to overwrite existing files, so if you call
this twice, it will die.

=cut


sub save_labels {
    my ($self, $where) = @_;
    if ((-e $where) && (! -d $where)) {
        die "$where exists and is not a directory" 
    }
    make_path($where);
    foreach my $pack ($self->packages) {
        my $name = File::Spec->catfile($where, "label" . $pack->{tracking_number} . "." . $pack->{ext});
        die "I should not overwrite $name!" if -e $name;
        open (my $fh, ">", $name) or die "cannot open $name $!";
        print $fh decode_base64($pack->{label});
        close $fh;
    }
}

=back

=cut


1;
