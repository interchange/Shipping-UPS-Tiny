package Shipping::UPS::Tiny::Package;

use 5.010001;
use strict;
use warnings FATAL => 'all';
use Scalar::Util qw/looks_like_number/;
use Moo;

=head1 NAME

Shipping::UPS::Tiny::Package - package class

=head1 ACCESSORS

=over 4

=item description

The description of the package.

=item type

Package types. Values are: 01 = UPS Letter, 02 = Customer Supplied
Package, 03 = Tube, 04 = PAK, 21 = UPS Express Box, 24 = UPS 25KG Box,
25 = UPS 10KG Box, 30 = Pallet, 2a = Small Express Box, 2b = Medium
Express Box, 2c = Large Express Box. Note: Only packaging type code 02
is applicable to Ground Freight Pricing (p.167 of the WebServices doc)

Default to 02, "Customer Supplied Package".

=item cm_kg

By default, centimeters and kilograms are used. Build the object
setting C<cm_kg> to a false value to use LBS and IN.

=back

The following values must be numerical. They use the unit of
measurement taken from the accessor above.

=over 4

=item length

=item width

=item height

=item weight


=cut

has description => (is => 'ro',
                    default => sub { return '' });
                   
my %package_types = (
                     '01' => 'UPS Letter',
                     '02' => 'Customer Supplied Package',
                     '03' => 'Tube',
                     '04' => 'PAK',
                     '21' => 'UPS Express Box',
                     '24' => 'UPS 25KG Box',
                     '25' => 'UPS 10KG Box',
                     '30' => 'Pallet',
                     '2a' => 'Small Express Box',
                     '2b' => 'Medium Express Box',
                     '2c' => 'Large Express Box',
                    );

has type => (is => 'ro',
             default => sub {
                 return '02';
             },
             isa => sub {
                 my $type = $_[0];
                 die unless $package_types{$type};
             });


has cm_kg => (is => 'ro',
              default => sub { return 1 });
              
has length => (is => 'ro',
               isa => sub {
                   die unless looks_like_number($_[0]);
               },
               required => 1);

has width => (is => 'ro',
              isa => sub {
                  die unless looks_like_number($_[0]);
              },
              required => 1);

has height => (is => 'ro',
               isa => sub {
                   die unless looks_like_number($_[0]);
               },
               required => 1);

has weight => (is => 'ro',
               isa => sub {
                   die unless looks_like_number($_[0]);
               },
               required => 1);


=back

=head1 METHODS

=over 4

=item as_hash

Build and return an hashref to feed the SOAP object.

=back

=cut

sub as_hash {
    my $self = shift;
    my ($cm, $kg);

    if ($self->cm_kg) {
        $cm = {
               Code => 'CM',
               Description => 'Centimeters',
              };
        $kg = {
               Code => 'KGS',
               Description => 'Kilograms',
              };
    }
    else {
        $cm = {
               Code => '',
               Description => 'Inches',
              };
        $kg = {
               Code => 'LBS',
               Description => 'Pounds',
              };
    }

    my $hash = {
                Description => $self->description,
                Packaging => {
                              Code => $self->type,
                              Description => $package_types{$self->type},
                             },
                # eventually use sprintf here, if we encounter problems
                Dimensions => {
                               UnitOfMeasurement => $cm,
                               Length => $self->length,
                               Width => $self->width,
                               Height => $self->height,
                              },
                PackageWeight => {
                                  UnitOfMeasurement => $kg,
                                  Weight => $self->weight,
                                 },
               };
    return $hash;
}


1;
