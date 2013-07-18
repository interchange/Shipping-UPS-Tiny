package Shipping::UPS::Tiny::Service;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Scalar::Util qw/looks_like_number/;
use Moo;

=head1 NAME

Shipping::UPS::Tiny::Package - package class

=head1 ACCESSORS

=over 4

=item service_code

The service code. By default: 11 (UPS Standard -- out of US, which
turns out to be the cheapest option).

Values are: 01 = Next Day Air, 02 = 2nd Day Air, 03 = Ground, 07 =
Express, 08 = Expedited, 11 = UPS Standard, 12 = 3 Day Select, 13 =
Next Day Air Saver, 14 = Next Day Air Early AM, 54 = Express Plus, 59
= 2nd Day Air A.M., 65 = UPS Saver, 82 = UPS Today Standard, 83 = UPS
Today Dedicated Courier, 84 = UPS Today Intercity, 85 = UPS Today
Express, 86 = UPS Today Express Saver, 96 = UPS Worldwide Express
Freight. Note: Only service code 03 is used for Ground Freight Pricing
shipments. 

P. 90 in the Webservice API doc.

=back

=cut

my %services = (
                "01" => "Next Day Air",
                "02" => "2nd Day Air",
                "03" => "Ground",
                "07" => "Express",
                "08" => "Expedited",
                "11" => "UPS Standard",
                "12" => "3 Day Select",
                "13" => "Next Day Air Saver",
                "14" => "Next Day Air Early AM",
                "54" => "Express Plus",
                "59" => "2nd Day Air A.M.",
                "65" => "UPS Saver",
                "82" => "UPS Today Standard",
                "83" => "UPS Today Dedicated Courier",
                "84" => "UPS Today Intercity",
                "85" => "UPS Today Express",
                "86" => "UPS Today Express Saver",
                "96" => "UPS Worldwide Express Freight",
               );


has service_code => (is => 'ro',
                     default => sub { return '11' },
                     isa => sub {
                         my $k = $_[0];
                         die "Wrong service code" unless $services{$k};
                     });

=head1 METHODS

=over 4

=item as_hash

Produce a comformant hash to feed the SOAP request.

=back

=cut

sub as_hash {
    my $self = shift;
    my $code = $self->service_code;
    my $desc = $services{$code};
    return {
            Code => $code,
            Description => $desc,
           };
}


1;
