package Shipping::UPS::Tiny::QuantumView;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Moo;

=head1 NAME

Shipping::UPS::Tiny::QuantumView -- class for QuantumView information

=head1 ACCESSORS

=head2 Credentials

=over 4

=item account_key

The kye provided by UPS

=item username

The username

=item password

=back

=cut

has 'account_key' => (is => 'ro',
                      required => 1);

has 'username' => (is => 'ro',
                   required => 1);

has 'password' => (is => 'ro',
                   required => 1);


1;
