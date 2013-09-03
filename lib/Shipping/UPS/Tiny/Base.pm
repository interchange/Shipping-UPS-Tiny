package Shipping::UPS::Tiny::Base;

use 5.010000;
use strict;
use warnings FATAL => 'all';

use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::Transport::SOAPHTTP;

use Shipping::UPS::Tiny::Address;
use Shipping::UPS::Tiny::CC;
use Shipping::UPS::Tiny::Package;
use Shipping::UPS::Tiny::Service;

use Moo;

=head1 NAME

Shipping::UPS::Tiny::Base - Base class for UPS API requests.


=head1 METHODS/ACCESSORS

=head2 Credentials (to be set in the constructor)

=over 4

=item account_key

The key provided by UPS

=item username

The username

=item ups_account 

the UPS Account shown in the request confirmation

=item password

=back

=cut

has 'account_key' => (is => 'ro',
                      required => 1);
                  

has 'username' => (is => 'ro',
                   required => 1);

has 'ups_account' => (is => 'ro',
                      required => 1);

has 'password' => (is => 'ro',
                   required => 1);


=head2 XML Schema (to be set in the constructor)

=over 4

=item schema_dir

Directory with the schema files.

=back

=cut


has 'schema_dir' => (is => 'ro',
                     required => 1,
                     isa => sub {
                         die "schema_dir $_[0] is not a directory"
                           unless -d $_[0];
                     });

=head2 SETTERS

=item shipper

The shipper. If not present, the details from C<from_address> are
used.

=item from_address

The origin address (read only, set by the method C<from>)

=item to_address

The destination  (read only, set by the method C<to>)

=item shipper_address

The shipper address (read only, set by the method C<shipper>)

=item negotiated_rates

Set this to a true value to signal UPS that you have negotiated rates.

=back

=cut

has from_address => (is => 'rwp');

has to_address => (is => 'rwp');

has shipper_address => (is => 'rwp');

has negotiated_rates => (is => 'rw');

=head1 METHODS

=head2 Addresses

The following methods set the origin and the destination of the
package. They accept an hashref as argument, using the keys described in
L<UPS::Shipment::Tiny::Address>

=over 4

=item from

=item to

=item shipper

This is optional and by default the values from the method C<from> are
taken.

=back

=head2 Package

=over 4

=item set_package(\%hash)

See L<UPS::Shipment::Tiny::Package> for the recognized keys.

Pass

=item package_props

Accessor to the package hashref.

=cut


sub from {
    my ($self, $args) = @_;
    # all is supposed to die here if the args are not validated.
    # eventually, wrap this in eval
    my $addr = Shipping::UPS::Tiny::Address->new(%$args);
    # build the shipper if not already set
    unless ($self->shipper_address) {
        $self->_build_shipper_address($args);
    };
    $self->_set_from_address($addr->as_hash);
};

sub to {
    my ($self, $args) = @_;
    my $addr = Shipping::UPS::Tiny::Address->new(%$args);
    $self->_set_to_address($addr->as_hash);
};

sub shipper {
    my ($self, $args) = @_;
    $self->_build_shipper_address($args);
}

sub _build_shipper_address {
    my ($self, $args) = @_;
    my $addr = Shipping::UPS::Tiny::Address->new(%$args);
    my $hash = $addr->as_hash;
    # add the shipper number, without it the request would fail
    if (my $acc = $self->ups_account) {
        $hash->{ShipperNumber} = $acc;
    }
    $self->_set_shipper_address($hash);
}


has package_props => (is => 'rwp');

sub set_package {
    my ($self, $args) = @_;
    my $pkg = Shipping::UPS::Tiny::Package->new(%$args);
    $self->_set_package_props($pkg->as_hash);
}

has _service_hash => (is => 'rw',
                      default => sub {
                          return Shipping::UPS::Tiny::Service->new->as_hash;
                      });

=item service

Select the service to use. The code is passed to a
L<Shipping::UPS::Service> object. See its documentation for the
available options.

=cut

sub service {
    my ($self, $code) = @_;
    if ($code) {
        $self->_service_hash(Shipping::UPS::Tiny::Service->new(service_code => $code)->as_hash);
    }
    return $self->_service_hash;
}

sub _credentials {
    my $self = shift;
    return {
            UsernameToken => {
                              Username => $self->username,
                              Password => $self->password,
                             },
            ServiceAccessToken => {
                                   AccessLicenseNumber => $self->account_key,
                                  },
           };
}


=back

=head2 SOAP related methods.

=over 4

=item debug_hash_request

The gigantic deep hash produced by the object is stored for further
inspection in this accessor.

=item debug_hash_response

Accessor to the hash returned by the last SOAP request.

=back

=cut

has debug_trace => (is => 'rwp');

has debug_hash_request => (is => 'rwp');

has debug_hash_response => (is => 'rwp');

=head2 INTERNALS

=over 4

=item soap ($operation)

The XML::Compile::SOAP client (internal)

=cut

has '_soap_obj' => (is => 'rwp');

sub soap {
    my ($self, $op) = @_;
    unless ($self->_soap_obj) {
        my $wsdl = XML::Compile::WSDL11->new($self->wsdlfile);
        my @schemas = 
        $wsdl->importDefinitions([ glob $self->schema_dir . "/*.xsd" ]);
        my $operation = $wsdl->operation($op);
        my $client = $operation->compileClient(endpoint => $self->endpoint);
        $self->_set__soap_obj($client);
    }
    return $self->_soap_obj;
}


=back

=cut


1;
