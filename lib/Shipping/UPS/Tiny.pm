package Shipping::UPS::Tiny;

use 5.010001;
use strict;
use warnings FATAL => 'all';

use Moo;
use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::Transport::SOAPHTTP;
use Shipping::UPS::Tiny::Address;
use Shipping::UPS::Tiny::Package;

=head1 NAME

Shipping::UPS::Tiny - The great new Shipping::UPS::Tiny!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Shipping::UPS::Tiny;

    my $foo = Shipping::UPS::Tiny->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 ACCESSORS

=head2 Credentials

=over 4

=item account_key

The kye provided by UPS

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


=head2 SOAP schemas and endpoint

=over 4

=item endpoint

It defaults to the development server,
L<https://wwwcie.ups.com/webservices/Ship>. When ready for production,
switch it to L<https://onlinetools.ups.com/webservices/Ship>

=item wsdlfile

You need to fetch the API documentation from UPS, in the Shipping.zip
package the wdsl is located at:

Shipping_Pkg/ShippingPACKAGE/PACKAGEWebServices/SCHEMA-WSDLs/Ship.wsdl

=item schema_dir

If I read correctly, the definitions are in 

Shipping_Pkg/ShippingPACKAGE/PACKAGEWebServices/SCHEMA-WSDLs

=cut


has 'endpoint' => (is => 'ro',
                   default => sub {
                       return 'https://wwwcie.ups.com/webservices/Ship';
                   });

has 'wsdlfile' => (is => 'ro',
                   isa => sub {
                       die "WDSL $_[0] is not a file"
                         unless -f $_[0];
                   });

has 'schema_dir' => (is => 'ro',
                     isa => sub {
                         die "schema_dir $_[0] is not a directory"
                           unless -d $_[0];
                     });

=item shipper

The shipper. If not present, the details from C<from_address> are
used.

=item from_address

The origin address (read only, set by the method C<from>)

=item to_address

The destination  (read only, set by the method C<to>)

=item shipper_address

The shipper address (read only, set by the method C<shippper>)

=back

=cut

has from_address => (is => 'rwp');

has to_address => (is => 'rwp');

has shipper_address => (is => 'rwp');

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

=back

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
    $hash->{ShipperNumber} = $self->ups_account;
    $self->_set_shipper_address($hash);
}


has package_props => (is => 'rwp');

sub set_package {
    my ($self, $args) = @_;
    my $pkg = Shipping::UPS::Tiny::Package->new(%$args);
    $self->_set_package_props($pkg->as_hash);
}


=head2 

=over 4 

=item ship("Description");

Ship the package with UPS and return a
L<Shipping::UPS::Tiny::Package::Response> object.

=back

=cut

sub ship {
    my ($self, $desc) = @_;
    if (defined $desc) {
        $self->_description($desc)
    };
    my $request = $self->_build_hash;
    my ($response, $trace) = $self->soap->($request, 'UTF-8');
    return $response, $trace;
}

has _description => (is => 'rw',
                     default => sub { return "" });

sub _build_hash {
    my $self = shift;
    my $req = {
               UPSSecurity => 
               {
                UsernameToken =>
                {
                 Username => $self->username,
                 Password => $self->password,
                },
                ServiceAccessToken =>
                {
                 AccessLicenseNumber => $self->account_key,
                },
               },
               Request =>
               {
                RequestOption => 'nonvalidate',
               },
               Shipment =>
               {
                Description => $self->_description,
                Shipper => $self->shipper_address,
                ShipTo => $self->to_address,
                ShipFrom => $self->from_address,
                Service => {
                            Code => '07',
                            Description => 'Express',
                           },
                Package => $self->package_props,
                PaymentInformation => $self->payment_info,
               },
               LabelSpecification =>
               {
                LabelImageFormat =>
                {
                 Code => 'GIF',
                 Description => 'GIF'
                },
                HTTPUserAgent => 'Mozilla/4.5'
               }
              };
    return $req;
}

# use bogus values for now, ok?
sub payment_info {
    my $self = shift;
    return {
            ShipmentCharge =>
            {
             Type => '01',
             BillShipper =>
             {
              CreditCard =>
              {
               Type => '06',
               Number => '4111111111111111',
               SecurityCode => '123',
               ExpirationDate => '12/2010',
               Address =>
               {
                AddressLine => '2010 warsaw road',
                City => 'Roswell',
                StateProvinceCode => 'GA',
                PostalCode => '30076',
                CountryCode => 'US'
               },
              },
             },
            },
           };
}


=head2 INTERNALS

=over 4

=item  soap

The XML::Compile::SOAP client (internal)

=cut

has '_soap_obj' => (is => 'rwp');

sub soap {
    my $self = shift;
    unless ($self->_soap_obj) {
        my $wsdl = XML::Compile::WSDL11->new($self->wsdlfile);
        my @schemas = 
        $wsdl->importDefinitions([ glob $self->schema_dir . "/*.xsd" ]);
        my $operation = $wsdl->operation('ProcessShipment');
        my $client = $operation->compileClient(endpoint => $self->endpoint);
        $self->_set__soap_obj($client);
    }
    return $self->_soap_obj;
}


=back

=head1 AUTHOR

Marco Pessotto, C<< <melmothx at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-shipping-ups-tiny at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Shipping-UPS-Tiny>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Shipping::UPS::Tiny


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Shipping-UPS-Tiny>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Shipping-UPS-Tiny>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Shipping-UPS-Tiny>

=item * Search CPAN

L<http://search.cpan.org/dist/Shipping-UPS-Tiny/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Marco Pessotto.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Shipping::UPS::Tiny
