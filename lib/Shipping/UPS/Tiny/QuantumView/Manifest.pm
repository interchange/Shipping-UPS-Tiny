package Shipping::UPS::Tiny::QuantumView::Manifest;
use 5.010000;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Shipping::UPS::Tiny::QuantumView::Package;
use Moo;

extends 'Shipping::UPS::Tiny::QuantumView::DetailsBase';

=head1 NAME Shipping::UPS::Tiny::QuantumView::Manifest

Subclass of L<Shipping::UPS::Tiny::QuantumView::DetailsBase>, which
provides the common accessor.

=head1 ACCESSORS

Additionally, the class provides the following accessors:

=over 4

=item shipper

Redundant field with the shipper details. Returned as hashref.

=item ship_to

Redundant field with details. Returned as hashref. 
This can be used to cross check in case of problems.

=cut

sub shipper {
    return shift->_unrolled_details("Shipper");
}

sub ship_to {
    return shift->_unrolled_details("ShipTo");
}

=item reference_number

Customer supplied reference number. Reference numbers are defined by
the shipper and can contain any character string.

This should be used to look up a package. The problem is that the
field may contain multiple ones, so it's returned as a list.

The field is not mandatory, so an empty list may be returned.

=cut


sub reference_numbers {
    my $self = shift;
    return $self->_get_ref_nums();
}

=item service_code

The service code used for the shipment (not mandatory)

=item service_description

The human readable description (not mandatory)

=cut

sub service_code {
    return shift->_service_hash->{Code} || "";
}

sub service_description {
    return shift->_service_hash->{Description} || "";
}

sub _service_hash {
    my $self = shift;
    my $service = $self->_unrolled_details("Service");
    if ($service) {
        # desc is not mandatory...
        unless (exists $service->{Description}) {
            $service->{Description} = "";
        }
        return $service;
    }
    else {
        return {
                Code => "",
                Service => "",
               };
    }
}

=item pickup_date

Should be set equal to the date on while the packages were picked up
(may be prior days date if the transmission occurs after midnight).

UPS returns it formatted as YYYYMMDD. We return it as YYYY-MM-DD,
which should be compatible with the mysql C<DATE> type.

It could be empty.

=item scheduled_delivery_date

The date the shipment originally was scheduled for delivery.

UPS returns it formatted as YYYYMMDD. We return it as YYYY-MM-DD,
which should be compatible with the mysql C<DATE> type.

It could be empty.

=item scheduled_delivery_time

No details are provided by the doc about the format beside a length of
6. So it's probably HHMMss.

=cut


sub pickup_date {
    my $self = shift;
    my $date = $self->_unrolled_details("PickupDate");
    return $self->_ups_date_to_iso_8601_date($date);
}

sub scheduled_delivery_date {
    my $self = shift;
    my $date = $self->_unrolled_details("ScheduledDeliveryDate");
    return $self->_ups_date_to_iso_8601_date($date);
}

sub scheduled_delivery_time {
    my $self = shift;
    my $time = $self->_unrolled_details("ScheduledDeliveryTime");
    return $self->_ups_time_to_iso_8601_time($time);
}

=item packages

More than the manifest itself, we're interested in the packages. So we
have to return a Shipping::UPS::Tiny::QuantumView::Package object which
inherit all the relevant data from the Manifest class.

=cut


sub packages {
    my $self = shift;
    my %inherit = $self->_relevant_data;
    my $details = $self->_unrolled_details("Package");
    my @packs;
    if ($details) {
        foreach my $detail (@$details) {
            my $data = $detail;
            my $pack = Shipping::UPS::Tiny::QuantumView::Package->new(%inherit,
                                                                      source => 'manifest',
                                                                      data => $detail);
            push @packs, $pack;
        }
    }
    return @packs;
}

sub _relevant_data {
    my $self = shift;
    my %data;
    foreach my $accessor (qw/subscription_number subscription_name subscription_status
                             subscription_status_desc file_status_desc file_name
                             shipper ship_to service_code service_description
                             scheduled_delivery_time scheduled_delivery_date
                             pickup_date/) {
        $data{$accessor} = $self->$accessor;
    }
    $data{manifest_reference_numbers} = [ $self->reference_numbers ];
    return %data;
}


1;

                          
