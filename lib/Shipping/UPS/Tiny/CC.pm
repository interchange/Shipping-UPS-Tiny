package Shipping::UPS::Tiny::CC;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Moo;

=head1 NAME

Shipping::UPS::Tiny::CC -- credit card info


=head1 OPTIONS/ACCESSORS

=head2 Mandatory

=over 4

=item type

Values are 01 = American Express, 03 = Discover, 04 = MasterCard, 05 =
Optima, 06 = VISA, 07 = Bravo, and 08 = Diners Club

=cut

my %ccs = (
           '01' => 'American Express',
           '03' => 'Discover',
           '04' => 'MasterCard',
           '05' => 'Optima',
           '06' => 'VISA',
           '07' => 'Bravo',
           '08' => 'Diners Club',
          );


has type => (is => 'ro',
             required => 1,
             isa => sub {
                 my $t = $_[0];
                 die "Invalid credit card type!" unless $ccs{$t};
             });

=item number

The credit card number

=cut

has number => (is => 'ro',
               required => 1,
               isa => sub {
                   die "CC number doesn't look like a number"
                     unless $_[0] =~ m/^[0-9]+$/
               });


=item sec_code

The security code

=cut

has sec_code => (is => 'ro',
                 required => 1,
                 isa => sub {
                     die "security number doesn't look like a number"
                       unless $_[0] =~ m/^[0-9]+$/
                 });


=item expire

expiration date, in MMYYYY format

=back

=cut

has expire => (is => 'ro',
               required => 1,
               isa => sub {
                   die "invalid format (MMYYYY)"
                     unless $_[0] =~ m/^[0-9]{6}$/;
               });

=head2 Optional

The address is not required if the ship from is not in US, CA or PR.

If you fail to provide one of the address details, the module will try
not to use the address information.

=over 4

=item address

=item city

=item province

=item postal_code

=item country

(the country code)

=back

=cut

has address => (is => 'rw');

has city => (is => 'rw');

has province => (is => 'rw');

has postal_code => (is => 'rw');

has country => (is => 'rw');

=head1 METHODS

=over 4

=item as_hash

=back

=cut

sub as_hash {
    my $self = shift;

    my $hash = {
                Type => $self->type,
                Number => $self->number,
                SecurityCode => $self->sec_code,
                ExpirationDate => $self->expire,
               };
    if ($self->address &&
        $self->city &&
        $self->postal_code &&
        $self->province &&
        $self->country) {
        $hash->{Address} = {
                            AddressLine => $self->address,
                            City => $self->city,
                            PostalCode => $self->postal_code,
                            StateProvinceCode => $self->province,
                            CountryCode => $self->country,
                           };
    }
    return $hash;
}

1;

