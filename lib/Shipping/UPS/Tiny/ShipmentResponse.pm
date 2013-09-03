package Shipping::UPS::Tiny::ShipmentResponse;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Moo;

extends 'Shipping::UPS::Tiny::ResponseBase';

use Data::Dumper;
use File::Spec;
use MIME::Base64 qw/decode_base64/;
use File::Path qw/mkpath/;

=head1 NAME

Shipping::UPS::Tiny::ShipmentResponse -- response class for Shipment requests

=head1 ACCESSORS/METHODS

This class extends the base class
L<Shipping::UPS::Tiny::ResponseBase>, which provides some share
methods and accessors.

Additionally, this class provides the following methods:

=over 4

=item ship_id

The shipment identification number.

=cut

sub ship_id {
    my $self = shift;
    return "" unless $self->is_success;
    return $self->_result->{ShipmentIdentificationNumber} || "";
}

=item billing_weight

The billing weight in numeric value. (KGS or LBS).

=item billing_weight_unit

The billing weight unit used, as returned by UPS (KGS or LBS).

=item billing_weight_in_grams

The billing weight in grams. It returns an integer without decimals.

=item billing_weight_details

The raw hash returned by UPS for the billing weight

=cut

sub billing_weight {
    my $self = shift;
    return "" unless $self->is_success;
    return $self->billing_weight_details->{Weight};
}

sub billing_weight_unit {
    my $self = shift;
    return "" unless $self->is_success;
    return $self->billing_weight_details->{UnitOfMeasurement}->{Code};
}

sub billing_weight_details {
    my $self = shift;
    return {} unless $self->is_success;
    die "Missing Billing weight!" unless $self->_result->{BillingWeight};
    return $self->_result->{BillingWeight};
}

sub billing_weight_in_grams {
    my $self = shift;
    my $unit = $self->billing_weight_unit;
    my $weight = $self->billing_weight;

#  international avoirdupois pound which is legally defined as exactly
#  0.45359237 kilograms. http://en.wikipedia.org/wiki/Pound_%28mass%29

    if ($unit eq 'KGS') {
        return sprintf('%d', $weight * 1000);
    }
    elsif ($unit eq 'LBS') {
        return sprintf('%d', $weight * 0.45359237 * 1000);
    }
    else {
        die "unrecognized unit $unit";
    }
}


=item shipment_charges

The total charge, as a string with total and currency, to be displayed.

=item shipment_charges_currency

The currency code returned by UPS for the shipment fee.

=cut

sub shipment_charges {
    my $self = shift;
    return "" unless $self->is_success;
    return sprintf('%.2f', $self->shipment_charges_details->{TotalCharges}->{MonetaryValue});
}

sub shipment_charges_currency {
    my $self = shift;
    return "" unless $self->is_success;
    return $self->shipment_charges_details->{TotalCharges}->{CurrencyCode};
}


=item shipment_charges_details

The details of the charges, as a hashref, taken verbatim from the
response.


=cut

sub shipment_charges_details {
    my $self = shift;
    return {} unless $self->is_success;
    die "Missing ShipmentCharges key!" unless exists $self->_result->{ShipmentCharges};
    return $self->_result->{ShipmentCharges};
}

=item packages

Returns (if success) the list of packages as a list of hashrefs, each
with the following keys:

    tracking_number # the tracking number
    html # the HTML in base64
    label # the image in  base64 
    ext  # extension
    label_filename # the filename where the label will be saved

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
            $pack_info->{label_filename} = "label" . $pack_info->{tracking_number}
              . "." . $pack_info->{ext};

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
    mkpath($where);
    foreach my $pack ($self->packages) {
        my $name = File::Spec->catfile($where, $pack->{label_filename});
        die "I should not overwrite $name!" if -e $name;
        open (my $fh, ">", $name) or die "cannot open $name $!";
        print $fh decode_base64($pack->{label});
        close $fh;
    }
}

=back

=cut


1;
