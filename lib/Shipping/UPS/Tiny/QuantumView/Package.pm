package Shipping::UPS::Tiny::QuantumView::Package;
use 5.010000;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Moo;

extends 'Shipping::UPS::Tiny::QuantumView::DetailsBase';

=head1 NAME Shipping::UPS::Tiny::QuantumView::Package

Subclass of L<Shipping::UPS::Tiny::QuantumView::DetailsBase>, which
provides the common accessor.

=head1 ACCESSORS

Additionally, the class provides the following accessors:

=over 4

=item shipper

=item ship_to

=item service_code

The service code used for the shipment (not mandatory)

=item service_description

The human readable description (not mandatory)

=item pickup_date

=item scheduled_delivery_date

=item scheduled_delivery_time

=item manifest_reference_numbers

=item source

The source of the data. E.g. "manifest".

=cut

has shipper => (is => 'ro');
has ship_to => (is => 'ro');
has service_code => (is => 'ro');
has service_description => (is => 'ro');
has pickup_date => (is => 'ro');
has scheduled_delivery_date => (is => 'ro');
has scheduled_delivery_time => (is => 'ro');
has source => (is => 'ro');
has manifest_reference_numbers => (is => 'ro');

=item tracking_number

The tracking number

=item reference_numbers

The reference number could be multiple. We return the list of reference numbers.

=cut

sub tracking_number {
    my $self = shift;
    return $self->_unrolled_details("TrackingNumber") || "";
}

sub reference_numbers {
    my $self = shift;
    my @list = $self->_get_ref_nums();
    unless (@list) {
        @list = @{ $self->manifest_reference_numbers };
    }
    return @list;
}

=item activities_datetime

A list of sql DATETIME strings (YYYY-MM-DD HH:MM:ss) with the package
activities. UPS doesn't specify what it's doing. Just "activity".

=back

=head1 MORE DETAILS



=cut


sub activities_datetime {
    my $self = shift;
    my $acts = $self->_unrolled_details("Activity");
    my @list;
    if ($acts) {
        foreach my $act (@$acts) {
            next unless exists $act->{Date};
            my $date = $self->_ups_date_to_iso_8601_date($act->{Date});
            my $time;
            if (exists $act->{Time} and defined $act->{Time}) {
                $time = $self->_ups_time_to_iso_8601_time($act->{Time});
            }
            else {
                # it will return 00:00:00
                $time = $self->_ups_time_to_iso_8601_time("n/a");
            }
            push @list, join (" ", $date, $time);
        }
    }
    return @list;
}

=item ship_to_as_string

Returns a string with the consegnee address.

=cut

sub ship_to_as_string {
    my $self = shift;
    # guaranteed to be present
    my $data = $self->ship_to;
    my @address;
    foreach my $k (qw/CompanyName AttentionName PhoneNumber EMailAddress LocationID/) {
        if (exists $data->{$k} and defined $data->{$k}) {
            push @address, $data->{$k};
        }
    }
    if (exists $data->{Address}) {
        foreach my $k (qw/ConsigneeName AddressLine1 AddressLine2 AddressLine3
                          PostalCode City StateProvinceCode CountryCode/) {
            if (exists $data->{Address}->{$k} and defined $data->{Address}->{$k}) {
                push @address, $data->{Address}->{$k};
            }
        }
    }
    return join (" ", @address);
}


1;
