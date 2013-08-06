package Shipping::UPS::Tiny::QuantumView::Exception;
use 5.010000;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Moo;

extends 'Shipping::UPS::Tiny::QuantumView::ExceptDeliveryBase';

=head1 NAME Shipping::UPS::Tiny::QuantumView::Exception

Subclass of L<Shipping::UPS::Tiny::QuantumView::DetailsBase>

=head1 ACCESSORS

=item source

The source of the data. (Defaults to "exception").

=cut


has source => (is => 'ro',
               default => sub { return "exception" });


=item exception_datetime

From the doc: Time that the package is delivered. (Which doesn't do
much sense..., being mandatory and being an exception. Delivered when?)

=cut

sub exception_datetime {
    return shift->datetime;
}


=item updated_address

The raw hashref of the updated address.

=item updated_address_as_string

The address as string

=item destination

Alias for C<updated_address_as_string>

=cut

sub updated_address {
    my $self = shift;
    return $self->_unrolled_details("UpdatedAddress");
}

sub updated_address_as_string {
    my $self = shift;
    my $hash = $self->updated_address;
    return $self->format_address($hash);
    
}

sub destination {
    return shift->updated_address_as_string;
}

=item details

The description, reason and resolution (with codes) of the exception

=item resolution

code and description of the resolution (if any)

=cut

sub details {
    my $self = shift;
    my $data = $self->data;
    my @out;
    foreach my $k (qw/StatusDescription StatusCode
                      ReasonDescription ReasonCode/) {
        if (exists $data->{$k} and defined $data->{$k}) {
            push @out, $data->{$k};
        }
    }
    if (my $resolution = $self->resolution) {
        push @out, $resolution;
    }
    if (@out) {
        return join(" ", @out);
    }
    return "";
}

sub resolution {
    my $self = shift;
    my $out = "";
    my $data = $self->_unrolled_details("Resolution");
    if ($data) {
        my @details = $data->{Code};
        if (my $desc = $data->{Description}) {
            push @details, $desc;
        }
        $out = join(" ",  @details);
    }
    return $out;
}

=item rescheduled_date

If present, the date to reschedule the package

=item scheduled_delivery_date

Alias for C<rescheduled_date>

=item rescheduled_time

If present, the time to reschedule the package

=cut

sub rescheduled_date {
    my $self = shift;
    my $date = $self->_unrolled_details("RescheduledDeliveryDate");
    return unless $date;
    return $self->_ups_date_to_iso_8601_date($date) 
}

sub rescheduled_time {
    my $self = shift;
    my $time = $self->_unrolled_details("RescheduledDeliveryTime");
    return unless $time;
    return $self->_ups_time_to_iso_8601_time($time);
}

sub scheduled_delivery_date {
    return shift->rescheduled_date;
}

1;
