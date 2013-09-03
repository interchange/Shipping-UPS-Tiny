package Shipping::UPS::Tiny;

use 5.010000;
use strict;
use warnings FATAL => 'all';

use File::Spec;
use Shipping::UPS::Tiny::ShipmentResponse;
use Shipping::UPS::Tiny::QuantumView;

use Moo;

extends 'Shipping::UPS::Tiny::Base';

=head1 NAME

Shipping::UPS::Tiny - Handle UPS API with L<XML::Compile>

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Shipping::UPS::Tiny;

    my $foo = Shipping::UPS::Tiny->new();
    ...

=head1 ACCESSORS


=head2 SOAP schemas and endpoint

=over 4

=item endpoint

It defaults to the development server,
L<https://wwwcie.ups.com/webservices/Ship>. When ready for production,
switch it to L<https://onlinetools.ups.com/webservices/Ship>

You need to fetch the API documentation from UPS, in the Shipping.zip
package the wdsl is located at:

Shipping_Pkg/ShippingPACKAGE/PACKAGEWebServices/SCHEMA-WSDLs/Ship.wsdl

=item schema_dir

The schema directory is the one provided by UPS:

C<Shipping_Pkg/ShippingPACKAGE/PACKAGEWebServices/SCHEMA-WSDLs>

So you have to pass the correct location of the directory.

=cut


has 'endpoint' => (is => 'ro',
                   default => sub {
                       return 'https://wwwcie.ups.com/webservices/Ship';
                   });

=item wsdlfile

For the shipping package, the wsdlfile is hardcoded as C<Ship.wsdl>,
which should be located in the schema_dir, as provided by UPS.

If UPS decides to change the naming schema, rename files, etc., it
means that this module will be obsolete and should be updated
accordingly.

=cut

sub wsdlfile {
    my $self = shift;
    my $wsdl = File::Spec->catfile($self->schema_dir, 'Ship.wsdl');
    die "$wsdl is not a file" unless -f $wsdl;
    return $wsdl;
}


=back

=head1 METHODS

The class inherits all the methods from L<Shipping::UPS::Tiny::Base>.
Additionally, the following methods are provided.

=head2 Addresses

=over 4

=item reference_number

Optional reference number to pass to UPS. The doc says (p.89)

Valid if the origin/destination pair is not US/US or PR/PR

=cut

has reference_number => (is => 'rw');

=item reference_number_type

If the reference number is set, you also need to set the type (by
code). Defaults to 'PO'.

Available options:

    Code Description                                      
    AJ   Accounts Receivable Customer Account             
    AT   Appropriation Number                             
    BM   Bill of Lading Number                            
    9V   Collect on Delivery (COD) Number                 
    ON   Dealer Order Number                              
    DP   Department Number                                
    3Q   Food and Drug Administration (FDA) Product Code  
    IK   Invoice Number                                   
    MK   Manifest Key Number                              
    MJ   Model Number                                     
    PM   Part Number                                      
    PC   Production Code                                  
    PO   Purchase Order Number                            
    RQ   Purchase Request Number                          
    RZ   Return Authorization Number                      
    SA   Salesperson Number                               
    SE   Serial Number                                    
    ST   Store Number                                     
    TN   Transaction Reference Number                     
    EI   Employer's ID Number                             
    TJ   Federal Taxpayer ID No.                          
    SY   Social Security Number
    

=cut

my %ref_num_types = (
    'AJ'   => 'Accounts Receivable Customer Account',
    'AT'   => 'Appropriation Number',
    'BM'   => 'Bill of Lading Number',
    '9V'   => 'Collect on Delivery (COD) Number',
    'ON'   => 'Dealer Order Number',
    'DP'   => 'Department Number',
    '3Q'   => 'Food and Drug Administration (FDA) Product Code',
    'IK'   => 'Invoice Number',
    'MK'   => 'Manifest Key Number',
    'MJ'   => 'Model Number',
    'PM'   => 'Part Number',
    'PC'   => 'Production Code',
    'PO'   => 'Purchase Order Number',
    'RQ'   => 'Purchase Request Number',
    'RZ'   => 'Return Authorization Number',
    'SA'   => 'Salesperson Number',
    'SE'   => 'Serial Number',
    'ST'   => 'Store Number',
    'TN'   => 'Transaction Reference Number',
    'EI'   => 'Employer’s ID Number',
    'TJ'   => 'Federal Taxpayer ID No.',
    'SY'   => 'Social Security Number',
);

has reference_number_type => (is => 'rw',
                              default => sub { return 'PO' },
                              isa => sub {
                                  my $code = $_[0];
                                  die "Wrong reference_number_type code!"
                                    unless $ref_num_types{$code};
                              });



=item address_validation

Set this to a true value to ask UPS to validate the address.

=cut

has address_validation => (is => 'rw');


=item credit_card_info(\%cc_info);

By default, this module use the account number as preferred method to
pay the UPS bill, to avoid sending each time the CC informations and
to store them somewhere.

If an hashref is passed to this setter, and passes the validation, the
credit card payment is used.

The hashref passed is passed to L<Shipping::UPS::Tiny::CC>, where the
validation happens.

=back

=cut

has credit_card_info => (is => 'rw',
                         isa => sub {
                             die "credit_card_info requires an hashref"
                               unless ref($_[0]) eq 'HASH';
                         });

=item ship("Description");

Ship the package with UPS and return a
L<Shipping::UPS::Tiny::Package::Response> object.

After calling C<ship>, the SOAP request is stored in the object and
can be accessed with C<debug_trace>

Tipical usage:

  $obj->ship("Nails for me");
  $obj->debug_trace->printRequest;
  $obj->debug_trace->printResponse;

=cut

sub ship {
    my ($self, $desc) = @_;
    if (defined $desc) {
        $self->_description($desc)
    };
    my $request = $self->_build_hash;
    my $res = $self->soap(ProcessShipment => $request);
    return Shipping::UPS::Tiny::ShipmentResponse->new(raw_response => $res);
}

has _description => (is => 'rw',
                     default => sub { return "" });


sub _label_spec {
    my $self = shift;
    return {
            LabelImageFormat => {
                                 Code => 'GIF',
                                 Description => 'GIF'
                                },
            HTTPUserAgent => 'Mozilla/4.5'
           };
}

sub _request_opts {
    my $self = shift;
    my $value = 'nonvalidate';

    if ($self->address_validation) {
        $value = 'validate';
    }

    return {
            RequestOption => $value
           };
}

sub _build_hash {
    my $self = shift;
    my $req = {
               UPSSecurity => $self->_credentials,
               Request => $self->_request_opts,
               Shipment => {
                            Description => $self->_description,
                            Shipper => $self->shipper_address,
                            ShipTo => $self->to_address,
                            ShipFrom => $self->from_address,
                            Service => $self->service,
                            Package => $self->package_props,
                            PaymentInformation => $self->payment_info,
                           },
               LabelSpecification => $self->_label_spec,
              };
    if ($self->reference_number) {
        $req->{Shipment}->{ReferenceNumber}->{Value} = $self->reference_number;
        $req->{Shipment}->{ReferenceNumber}->{Code} = $self->reference_number_type;
    }
    if ($self->negotiated_rates) {
        $req->{Shipment}->{ShipmentRatingOptions}->{NegotiatedRatesIndicator} = "";
    }
    return $req;
}


=item payment_info

Internal method to build the billing information. It will use the CC
if C<credit_card_info> is set.

=back


=cut

sub payment_info {
    my $self = shift;
    my $hash = {
                ShipmentCharge => {
                                   Type => '01', # transportation
                                   BillShipper => {}
                                  }
               };
    if (my $details = $self->credit_card_info) {
        $hash->{ShipmentCharge}->{BillShipper}->{CreditCard} =
          Shipping::UPS::Tiny::CC->new(%$details)->as_hash;
    }
    else {
        $hash->{ShipmentCharge}->{BillShipper}->{AccountNumber} =
          $self->ups_account;
    }
    return  $hash;
}


=head2 Quantum View

Quantum View provides access to the details about the shipments.

If there is a named subscription, only the selected data will be
retrieved. No subscription means retrieving of the full batch of data.

The following method return a L<Shipping::UPS::Tiny::QuantumView>
object, inheriting the credential from this module. Depending on the
user case, you may want to use L<Shipping::UPS::Tiny::QuantumView> as
a standalone module.

=head3 quantum_view(option1 => value, option2 => value)

Please refer to L<Shipping::UPS::Tiny::QuantumView> for the possible
options.

Anyway, if called from here, we inject the existing credentials if
they are not passed as argument.

=cut

sub quantum_view {
    my $self = shift;
    die "please pass the argument as a plain paired list" if (@_ % 2);
    my %args = @_;
    foreach my $k (qw/username account_key password/) {
        unless (exists $args{$k}) {
            $args{$k} = $self->$k;
        }
    }
    return Shipping::UPS::Tiny::QuantumView->new(%args);
}




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
