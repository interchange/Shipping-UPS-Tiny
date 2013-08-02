package Shipping::UPS::Tiny::QuantumView::DetailsBase;
use 5.010000;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Moo;

=head1 ACCESSORS

=head2 Manifest/Delivery/Exception  metadata

These accessors point to the file from which the data come from, which
for unknown reason is first splat in Events, and then in files. So we
track them here, in case it's needed somewhere.

=over 4

=item subscription_number

=item subscription_name

=item subscription_status

=item subscription_status_desc

=item file_status_desc

=file file_status

=item file_name

=back

=cut

has subscription_number => (is => 'ro',
                          default => sub { return "" });

has subscription_name => (is => 'ro',
                          default => sub { return "" });

has subscription_status => (is => 'ro',
                            default => sub { return "" });


has subscription_status_desc => (is => 'ro',
                                 default => sub { return "" });

has file_status_desc => (is => 'ro',
                         default => sub { return "" });

has file_status => (is => 'ro',
                    default => sub { return "" });

has file_name => (is => 'ro',
                  default => sub { return "" });

has data => (is => 'ro');


1;

                          
