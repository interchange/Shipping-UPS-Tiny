package Shipping::UPS::Tiny::QuantumView::Delivery;
use 5.010000;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Moo;

extends 'Shipping::UPS::Tiny::QuantumView::ExceptDeliveryBase';

=head1 NAME Shipping::UPS::Tiny::QuantumView::Delivery

Subclass of L<Shipping::UPS::Tiny::QuantumView::ExceptDeliveryBase>

=head1 ACCESSORS

=over 4

=item source

The source of the data. (Defaults to "delivery").

=cut


has source => (is => 'ro',
               default => sub { return "delivery" });

=item delivery_datetime

The delivery DATETIME (iso 8061)

=item delivery_location_address

The hashref with the delivery location details. p.70-71 of the doc.

=item delivery_location_address_as_string

The address as a single string.

=item destination

Alias for C<delivery_location_address_as_string>

=item delivery_location

Code and description of the delivery location.

=item signed_by

The name of the person who signed the delivery.

=item details

For the delivery, the details contains the C<signed_by> field.

=cut

sub delivery_datetime {
    return shift->datetime;
}

sub _delivery_location_hash {
    my $self = shift;
    return $self->_unrolled_details("DeliveryLocation");
}

sub delivery_location_address {
    my $self = shift;
    if (my $root = $self->_delivery_location_hash) {
        # mandatory if the DeliveryLocation is present
        return $root->{AddressArtifactFormat};
    }
    return;
}

sub delivery_location_address_as_string {
    my $self = shift;
    my $hash = $self->delivery_location_address;
    # given that there are 15 keys, all of them non mandatory, the
    # idea is to output them in an array when they exist, in an order
    # which could actually make sense(name, street, etc.), and then
    # join them by a space. We should already know to whom we sent the
    # package, so it should be just a way to cross-check.

    # We also skip "AddressExtendedInformation" whose purpose is
    # unknown and has only Type, Low, High. Mah!
    return $self->format_address($hash);
}

sub destination {
    return shift->delivery_location_address_as_string;
}

sub signed_by {
    my $self = shift;
    if (my $loc = $self->_delivery_location_hash) {
        if (my $name = $loc->{SignedForByName}) {
            return $name;
        }
    }
    return "";
}

sub details {
    my $self = shift;
    return join(" ", $self->delivery_location, $self->signed_by);
}


sub delivery_location {
    my $self = shift;
    my $string;
    if (my $loc = $self->_delivery_location_hash) {
        my @out;
        if (my $desc = $loc->{Description}) {
            push @out, $desc;
        }
        if (my $code = $loc->{Code}) {
            push @out, $code;
        }
        if (@out) {
            $string = join(" ", @out);
        }
    }
    return $string;
}

=item Cash on Delivery is not implemented by us.

=back

=cut

1;

                          
