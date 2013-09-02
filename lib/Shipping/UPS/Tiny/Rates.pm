package Shipping::UPS::Tiny::Rates;

use 5.010000;
use strict;
use warnings FATAL => 'all';

use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::Transport::SOAPHTTP;

use Moo;

extends "Shipping::UPS::Tiny";

=head1 NAME

Shipping::UPS::Tiny::Rating - retrieve the UPS rates for a package.

=head1 DESCRIPTION

This module inherits as much as possible from L<Shipping::UPS::Tiny>.

The C<schemadir> option can't be shared with the parent module, and
must point to another directory.


=head1 SYNOPSIS

See the rating.t testfile until I write this

=head1 ACCESSORS

=head2 Required options (to be passed to the constructor)

=over 4

=item username 

=item password (required)

=item account_key (required)

=item schema_dir (required)

=back

=head2 Read-only accessors

=over 4

=item wsdlfile

For The Shipping Package, the WSDL file is hardcoded as C<RateWS.wsdl>
which should be located in the C<schema_dir>, as provided by UPS.

If UPS decides to change the naming schema, rename files, etc., it
means that this module will be obsolete and should be updated
accordingly.

=back

=cut

sub wsdlfile {
    my $self = shift;
    my $wsdl = File::Spec->catfile($self->schema_dir, 'RateWS.wsdl');
    die "$wsdl is not a file" unless -f $wsdl;
    return $wsdl;
}


=item ups_account

This option is required for negotiated rates.

=item endpoint

By default the SOAP request will be done against the development site:

L<https://wwwcie.ups.com/webservices/Rate>

For production point this to

L<https://onlinetools.ups.com/webservices/Rate>

=cut

# override the required => 1 from Tiny.pm

has 'ups_account' => (is => 'ro',
                      required => 0);


has endpoint => (is => 'ro',
                 default => sub {
                     return 'https://wwwcie.ups.com/webservices/Rate';
                 });


=item request_type

C<Rate>: The server rates.

C<Shop>: The server validates the shipment, and return rates for all UPS
products from the ShipFrom to the ShipTo addresses.

Default: Shop.

=cut

has request_type => (is => 'rw',
                     # keep this as default for now
                     default => sub { return 'Shop'; },
                     isa => sub {
                         my $type = $_[0];
                         die "Wrong request type $type"
                           unless ($type eq 'Shop' or $type eq 'Rate') 
                       });

sub _request_opts {
    my $self = shift;
    return {
            RequestOption => $self->request_type,
           };
}

=item customer_reference

An arbitrary string which will be echoed back by the server. (max 512 chars)

=cut

has customer_reference => (is => 'rw',
                           default => sub { return '' },
                           isa => sub {
                               die "reference too long" if length($_[0]) > 512;
                           });



=item pickup_type

Default value is 01. Valid values

01 - Daily Pickup;
03 - Customer Counter;
06 - One Time Pickup;
07 - On Call Air;
19 - Letter Center;
20 - Air Service Center.

Pickup Type Code If invalid value is provided, 01 will be used
(enforced by the server).

=cut

my %pickups = (
               '01' =>  'Daily Pickup',
               '03' =>  'Customer Counter',
               '06' =>  'One Time Pickup',
               '07' =>  'On Call Air',
               '19' =>  'Letter Center',
               '20' =>  'Air Service Center',
              );

has pickup_type => (is => 'rw',
                    default => sub { '01' },
                    isa => sub {
                        die "Invalid pickup type" unless $pickups{$_[0]};
                    });




# build the request
sub _build_hash {
    my $self = shift;

    # basic stuff
    my $req = {
               UPSSecurity => $self->_credentials,
               Request => $self->_request_opts,
              };


    # some non mandatory options
    if (my $ref = $self->customer_reference) {
        $req->{TransactionReference}->{CustomerContext} = $ref;
    }

    # pickup
    if (my $pickup = $self->pickup_type) {
        $req->{PickupType}->{Code} = $pickup;
    }

    # here there would be room for customer classification, but its
    # purpose is unclear and only for US shippers.

    # here we use the inherited methods and hope for the be(a)st
    $req->{Shipment} = {
                        Shipper => $self->shipper_address,
                        ShipTo => $self->to_address,
                        ShipFrom => $self->from_address,
                        # Service => $self->service,
                        Package => [ $self->package_props ],
                       };

    # service is not needed if the request type is Shop
    if ($self->request_type eq 'Rate') {
        $req->{Shipment}->{Service} = $self->service;
    }

    # and here comes the hack: the UPS geniuses don't use a consistent
    # schema for shipper, packages, etc. so, instead of building
    # another class, we delete the unused info, where the thing barfs.
    foreach my $f (qw/Shipper ShipTo ShipFrom/) {
        foreach my $del (qw/Phone AttentionName TaxIdentificationNumber/) {
            delete $req->{Shipment}->{$f}->{$del};
        }
    }

    foreach my $p (@{ $req->{Shipment}->{Package}}) {
        delete $p->{Description};
        $p->{PackagingType} = delete $p->{Packaging};
    }
    return $req;
}

=item rate

The main method.

=cut 


sub rate {
    my $self = shift;
    my $request = $self->_build_hash;
    $self->_set_debug_hash_request($request);
    my ($response, $trace) = $self->soap->($request, 'UTF-8');

    $self->_set_debug_trace($trace);
    $self->_set_debug_hash_response($response);
    if ($response->{Fault}) {
        return;
    }

    # for now let spits out the details without too many details.
    # The response should be incapsulated in an object
    my @results;
    if (my $services = $response->{Body}->{RatedShipment}) {
        foreach my $s (@$services) {
            push @results, [ $s->{Service}->{Code} => $s->{TotalCharges}->{MonetaryValue} . " " . $s->{TotalCharges}->{CurrencyCode}  ]
        }
    }
    return @results;
}


=item  soap

The XML::Compile::SOAP client (internal)

=cut

sub soap {
    my $self = shift;
    unless ($self->_soap_obj) {
        my $wsdl = XML::Compile::WSDL11->new($self->wsdlfile);
        my @schemas = 
        $wsdl->importDefinitions([ glob $self->schema_dir . "/*.xsd" ]);
        my $operation = $wsdl->operation('ProcessRate');
        my $client = $operation->compileClient(endpoint => $self->endpoint);
        $self->_set__soap_obj($client);
    }
    return $self->_soap_obj;
}



=back

=cut

1;
