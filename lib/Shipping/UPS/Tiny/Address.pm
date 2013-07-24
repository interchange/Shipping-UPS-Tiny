package Shipping::UPS::Tiny::Address;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Moo;

=head1 NAME

Shipping::UPS::Tiny::Address - Address object

=head1 ACCESSORS

=over 4

=item name

On the label, this field is used as "Attention name". 

=item company

On the label, UPS refers to this as "Name". If not provided, the value
of the above accessor C<name> will be used.

=item address

=item province

(or state for US)

=item city

=item postal_code

=item country

=item phone

=item phone_ext

=item tax_id

Tax identification number

=cut

has name => (is => 'ro',
             required => 1);

has company => (is => 'ro');

has address => (is => 'ro',
                required => 1);

has city => (is => 'ro',
             required => 1);

has province => (is => 'ro',
                 default => sub { return "" });

has postal_code => (is => 'ro',
                    required => 1);

has country => (is => 'ro',
                isa => sub {
                    die "country must be a country code"
                      unless $_[0] =~ m/^[A-Z]{2,3}+$/s;
                },
                required => 1);

has phone => (is => 'ro',
              # maybe add validation?
              required => 1);


has phone_ext => (is => 'ro');

has tax_id => (is => 'ro');

=item as_hash

Output the address an an hash ready for L<XML::Compile::SOAP>

=cut

sub as_hash {
    my $self = shift;
    # mandatory fields
    my $addr = {
                Name => $self->company || $self->name,
                AttentionName => $self->name,
                Address => {
                            AddressLine => $self->address,
                            City => $self->city,
                            StateProvinceCode => $self->province,
                            PostalCode => $self->postal_code,
                            CountryCode => $self->country,
                           },
                Phone => {
                          Number => $self->phone,
                         }
               };
    # optional fields
    if (defined $self->phone_ext) {
        $addr->{Phone}->{Extension} = $self->phone_ext;
    }
    if (defined $self->tax_id) {
        $addr->{TaxIdentificationNumber} = $self->tax_id;
    }
    return $addr;
}

=back

=cut


1;
