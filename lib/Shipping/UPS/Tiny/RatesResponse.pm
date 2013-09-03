package Shipping::UPS::Tiny::RatesResponse;

use 5.010000;
use strict;
use warnings FATAL => 'all';

use Shipping::UPS::Tiny::Service;


use Moo;

extends 'Shipping::UPS::Tiny::ResponseBase';

=head1 NAME

Shipping::UPS::Tiny::RatesResponse -- response class for Rates requests

=head1 ACCESSORS/METHODS

=head1 ACCESSORS/METHODS

This class extends the base class
L<Shipping::UPS::Tiny::ResponseBase>, which provides some share
methods and accessors.

Additionally, this class provides the following methods:

=over 4

=item list_rates

Returns a list of hashrefs with the following keys:

=over 4

=item code: the code of the service

=item name: the human readable name of the service

=item charge: the total charge for the shipment

=item currency: the currency used for the charging

=back

=cut

sub list_rates {
    my $self = shift;
    my $results = $self->_result;
    # this is an arrayref
    my @list;
    return @list unless $results;
    foreach my $p (@$results) {
        my $details = {
                       # guaranteed to be present
                       code => $p->{Service}->{Code},
                       charge => $p->{TotalCharges}->{MonetaryValue},
                       currency => $p->{TotalCharges}->{CurrencyCode},
                      };
        # assign a name to the service
        my $name = Shipping::UPS::Tiny::Service
          ->new(service_code => $details->{code})
            ->service_name;
        $details->{name} = $name;

        # here there is room, for example, for guaranteed delivery and
        # charge details (like billing weight), but should be
        # implemented on demand as the bottom line is that we just
        # want to know how much the shipping costs, not how is
        # computed. If it's too expensive, it's too expensive.

        push @list, $details;
    }
    # sort the list by cost
    return sort { $a->{charge} <=> $b->{charge} } @list;
}


=back

=cut


1;
