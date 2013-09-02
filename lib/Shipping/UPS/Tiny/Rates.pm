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

This option is not required.

=cut

has 'ups_account' => (is => 'ro',
                      required => 0);


1;
