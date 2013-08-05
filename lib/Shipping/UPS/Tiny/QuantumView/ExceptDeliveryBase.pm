package Shipping::UPS::Tiny::QuantumView::ExceptDeliveryBase;
use 5.010000;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Moo;

extends 'Shipping::UPS::Tiny::QuantumView::DetailsBase';

=head1 NAME Shipping::UPS::Tiny::QuantumView::Exception

Subclass of L<Shipping::UPS::Tiny::QuantumView::DetailsBase> with
shared methods between Delivery and Exception;

=head1 ACCESSORS

=head1 ACCESSORS

=item tracking_number

The tracking number of the package. It's guaranteed to be present.

=item reference_numbers

The reference number could be multiple. We return the list of
reference numbers from both the shipment and the packages. Not
guaranteed to be populated.

=cut

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

sub datetime {
    my $self = shift;
    return $self->_ups_datetime_to_iso8601($self->_unrolled_details("Date"),
                                           $self->_unrolled_details("Time"));
}

=item activity_location

Location of the the activity (if any).

=cut

sub activity_location {
    my $self = shift;
    my $out = "";
    if (my $loc = $self->_unrolled_details("ActivityLocation")) {
        if (exists $loc->{AddressArtifactFormat}) {
            my @details;
            foreach my $k (qw/PoliticalDivision2 PoliticalDivision1 CountryCode/) {
                if (exists $loc->{AddressArtifactFormat}->{$k}) {
                    push @details, $loc->{AddressArtifactFormat}->{$k};
                }
            }
            if (@details) {
                $out = join(" ", @details);
            }
        }
    }
    return $out;
}

1;
