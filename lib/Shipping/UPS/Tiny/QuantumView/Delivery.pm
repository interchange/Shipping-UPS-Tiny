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

=item tracking_number

The tracking number of the package. It's guaranteed to be present.

=item reference_numbers

The reference number could be multiple. We return the list of
reference numbers from both the shipment and the packages. Not
guaranteed to be populated.

=item source

The source of the data. (Defaults to "delivery").

=cut


has source => (is => 'ro',
               default => sub { return "delivery" });

sub tracking_number {
    my $self = shift;
    return $self->_unrolled_details('TrackingNumber');
}

sub reference_numbers {
    my $self = shift;
    my @nums;
    foreach my $type (qw/PackageReferenceNumber ShipmentReferenceNumber/) {
        if (my $numsref = $self->_unrolled_details($type)) {
            foreach my $num (@$numsref) {
                push @nums, $num->{Value};
            }
        }
    }
    return @nums;
}



=item delivery_datetime

The delivery DATETIME (iso 8061)

=cut

sub delivery_datetime {
    return shift->datetime;
}



1;

                          
