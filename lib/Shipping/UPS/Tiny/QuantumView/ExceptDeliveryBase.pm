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

=item reference_numbers

The reference number could be multiple. We return the list of
reference numbers from both the shipment and the packages. Not
guaranteed to be populated.

=item reference_number

If multiple reference numbers are found, return just the first or the
empty string.

=cut

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

sub reference_number {
    my $self = shift;
    my @nums = $self->reference_numbers;
    return "" unless (@nums);
    return shift(@nums);
}

=item datetime

Timestamp of the operation

=item latest_activity

Alias for C<datetime>

=cut

sub datetime {
    my $self = shift;
    return $self->_ups_datetime_to_iso8601($self->_unrolled_details("Date"),
                                           $self->_unrolled_details("Time"));
}

sub latest_activity {
    return shift->datetime;
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

=item format_address(\%address)

Return the address (as provided by Delivery and Exception) as a string.

=cut

sub format_address {
    my ($self, $hash) = @_;
    return "" unless $hash;
    my @address;
    foreach my $k (qw/ConsigneeName
                      BuildingName
                      StreetPrefix StreetType StreetName StreetSuffix
                      StreetNumberLow
                      PostcodePrimaryLow PostcodeExtendedLow
                      PoliticalDivision3 PoliticalDivision2 PoliticalDivision1
                      CountryCode/) {
        if (exists $hash->{$k} and defined $hash->{$k}) {
            push @address, $hash->{$k};
        }
    }
    if (@address) {
        return join (" ", @address);
    }
    else {
        return "";
    }
}

1;
