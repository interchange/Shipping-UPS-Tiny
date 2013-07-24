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

The value accepted has max 35 characters, and only 25 will be used in
the label (30 in the From field).

We trim the value without issuing warnings if it exceedes the limit.

=item company

On the label, UPS refers to this as "Name". If not provided, the value
of the above accessor C<name> will be used.

The value accepted has max 35 characters, and only 25 will be used in
the label (30 in the From field).

We trim the value without issuing warnings if it exceedes the limit.

=item address

The value accepted has max 35 characters, and only 25 will be used in
the label (30 in the From field).

We trim the value without issuing warnings if it exceedes the limit.

=item province

(or state for US). This is mandatory only if shipping to US or CA.

=item city

The value accepted has max 30 characters, and only 15 will be used in
the label.

We trim the value without issuing warnings if it exceedes the limit.

=item postal_code

=item country

Country code.

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
    my $name = $self->company || $self->name;
    my $addr = {
                Name => substr($name, 0, 35),
                AttentionName => substr($self->name, 0, 35),
                Address => {
                            AddressLine => substr($self->address, 0, 35),
                            City => substr($self->city, 0, 30),
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
