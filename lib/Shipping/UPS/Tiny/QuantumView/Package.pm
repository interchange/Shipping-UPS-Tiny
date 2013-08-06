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

=item reference_numbers

The reference number could be multiple. We return the list of reference numbers.

=item reference_number

If multiple reference numbers are found, return just the first or the
empty string.

=cut

sub reference_numbers {
    my $self = shift;
    my @list = $self->_get_ref_nums();
    unless (@list) {
        @list = @{ $self->manifest_reference_numbers };
    }
    return @list;
}

sub reference_number {
    my $self = shift;
    my @nums = $self->reference_numbers;
    return "" unless (@nums);
    return shift(@nums);
}



=item activities_datetime

A list of sql DATETIME strings (YYYY-MM-DD HH:MM:ss) with the package
activities. UPS doesn't specify what it's doing. Just "activity".

=cut


sub activities_datetime {
    my $self = shift;
    my $acts = $self->_unrolled_details("Activity");
    my @list;
    if ($acts) {
        foreach my $act (@$acts) {
            next unless exists $act->{Date};
            push @list, $self->_ups_datetime_to_iso8601($act->{Date},$act->{Time});
        }
    }
    return @list;
}

=item latest_activity

Returns the most recent activity date.

=cut

sub latest_activity {
    my $self = shift;
    my @acts = $self->activities_datetime;
    return unless @acts; # no date :-\
    if (@acts == 1) {
        return shift(@acts);
    }
    else {
        my @sorted = sort { $a cmp $b } @acts;
        return pop(@sorted);
    }
}

=item activity_location

Not relevant. Returns "origin", beign a manifest".

=cut

sub activity_location {
    my $self = shift;
    return "origin";
}


=item ship_to_as_string

Returns a string with the consegnee address.

=item destination

Alias of C<ship_to_as_string>

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

sub destination {
    return shift->ship_to_as_string;
}

1;
