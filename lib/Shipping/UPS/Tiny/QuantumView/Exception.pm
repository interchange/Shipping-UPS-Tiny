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

=item location

Location of the exception (if any).

=cut

sub location {
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

=item updated_address

The raw hashref of the updated address. To be serialized?

=cut

sub updated_address {
    my $self = shift;
    return $self->_unrolled_details("UpdatedAddress");
}

=item description

The description (with code) of the exception

=item resolution

code and description of the resolution (if any)

=cut

sub description {
    my $self = shift;
    my $data = $self->data;
    my @out;
    foreach my $k (qw/StatusDescription StatusCode
                      ReasonDescription ReasonCode/) {
        if (exists $data->{$k} and defined $data->{$k}) {
            push @out, $data->{$k};
        }
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

=item rescheduled_time

If present, the time to reschedule the package

=cut

sub rescheduled_date {
    my $self = shift;
    my $date = $self->_unrolled_details("RescheduledDeliveryDate");
    return "" unless $date;
    return $self->_ups_date_to_iso_8601_date($date) 
}

sub rescheduled_time {
    my $self = shift;
    my $time = $self->_unrolled_details("RescheduledDeliveryTime");
    return unless $time;
    return $self->_ups_time_to_iso_8601_time($time);
}


1;

                          
