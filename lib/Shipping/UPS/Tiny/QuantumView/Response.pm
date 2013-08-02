package Shipping::UPS::Tiny::QuantumView::Response;

use 5.010000;
use strict;
use warnings FATAL => 'all';
use Date::Parse;
use File::Spec;
use XML::LibXML::Simple qw/XMLin/;
use POSIX qw/strftime/;
use Scalar::Util qw/blessed/;
use Data::Dumper;
use Moo;

=head1 NAME

Shipping::UPS::Tiny::QuantumViewResponse -- class for QuantumView response

=head1 METHODS/ACCESSORS

=head3 response

The response. This can be either a reference to a string or a
HTTP::Response object, or string with a filename with the response
content. It B<must> be set in the constructor.

=cut

has response => (is => 'ro',
                 trigger => 1,
                 required => 1);

sub _trigger_response  {
    my ($self, $value) = @_;
    # todo: handle undef values, undef content, etc. etc.

    if (blessed($value)) {
        # it's an LWP object;
        if ($value->is_success)  {
            my $parsed;
            eval {
                $parsed = XMLin($value->content);
            };
            if ($@) {
                $self->error($@);
            }
            elsif (!$parsed) {
                $self->error("the parsed ref to a scalar returned nothing");
            }
            else {
                $self->_set_parsed_data($parsed);
            }
        }
        else {
            $self->error($value->status_line);
        }
    }
    else {
        my $body;
        if (ref($value) eq 'SCALAR') {
            $body = $$value;
        }
        else {
            $body = $value;
        }
        # we got a reference to the xml body
        my $parsed;
        eval {
            $parsed = XMLin($body);
        };
        if ($@) {
            $self->error($@);
        }
        elsif (!$parsed) {
            $self->error("the parsed ref to a scalar returned nothing");
        }
        else {
            $self->_set_parsed_data($parsed);
        }
    }
    unless ($self->parsed_data) {
        # we screwed up, so we populate the data with an equivalent fake response
        $self->_set_parsed_data({
                                 Response => {
                                              ResponseStatusCode => 0,
                                              ResponseStatusDescription => 'Failure',
                                              Error => {
                                                        'ErrorDescription' => $self->error,
                                                        'ErrorCode' => '999999',
                                                        'ErrorSeverity' => 'Hard'
                                                       }
                                             }
                                });
    }
}


=head3 error

The error as set by the I<parser>. Mostly internal.

=head3 parsed_data

The raw parsed XML document as Perl data.

=head3 response_section

The "QuantumViewResponse/Response" xpath of the response. Contains
metadata for error handling and asserting the success.

=head3 is_success

Returns true if there is a success. 

=head3 is_failure

Returns true if there is a failure.

=head3 error_desc

Returns a string that flattens the data found in the Error stanza of
the Response.

=cut

has error => (is => 'rw',
              default => sub { return "" });

has parsed_data => (is => 'rwp');

sub response_section {
    my $self = shift;
    return { %{$self->parsed_data->{Response}} };
}

sub is_success {
    my $self = shift;
    # response status code is guaranteed to be present
    return $self->response_section->{ResponseStatusCode};
}

sub is_failure {
    my $self = shift;
    if ($self->is_success) {
        return;
    }
    return $self->response_section->{ResponseStatusDescription};
}

sub error_desc {
    my $self = shift;
    my $data = $self->response_section;
    return "" unless exists $data->{Error};
    # flatten the hash.
    my %error = %{$data->{Error}};
    my @out;
    foreach my $k(keys %error) {
        my $error_detail;
        if (ref($error{$k})) {
            $error_detail = Dumper($error{$k});
        }
        else {
            $error_detail = $error{$k};
        }
        push @out, "$k: " . ($error_detail || "");
    }
    return join(" ", @out) || "Unparsed error!";
}



=head3 qv_section

Returns the main hashref with the actual QV data.
We get a structure like this inside:

  $VAR1 = {
    'SubscriptionEvents' => [
        {
            'Number' => '21B6D76A8B32564B',
            'SubscriptionFile' => [
                {
                    'Delivery' => 'ARRAY(0x23d3848)',
                    'StatusType' => 'HASH(0x23def08)',
                    'FileName' => '020208_133243003',
                    'Origin' => 'HASH(0x23d3140)'
                   },
                {
                    'Manifest' => 'ARRAY(0x23cdf00)',
                    'StatusType' => 'HASH(0x25de940)',
                    'FileName' => '020211_133241001'
                   }
               ],
            'SubscriptionStatus' => {
                'Code' => 'A',
                'Description' => 'Active'
               },
            'Name' => 'IVS'
           },
        {
            'Number' => '21B6D76A8B32564C',
            'SubscriptionFile' => [
                {
                    'Exception' => 'HASH(0x28c8978)',
                    'Delivery' => 'ARRAY(0x28c91d0)',
                    'Manifest' => 'ARRAY(0x2407ca8)',
                    'StatusType' => 'HASH(0x23d2960)',
                    'FileName' => '020208_133242002'
                   },
                {
                    'Delivery' => 'ARRAY(0x23e9320)',
                    'StatusType' => 'HASH(0x25cd850)',
                    'FileName' => '020208_133244004',
                    'Origin' => 'HASH(0x23e5e40)'
                   }
               ],
            'SubscriptionStatus' => {
                'Code' => 'A',
                'Description' => 'Active'
               },
            'Name' => 'OVS'
           }
       ],
    'SubscriberID' => 'xxxx'
   };


At full depth, but with arrays cut down:


  $VAR1 = {
    'SubscriptionEvents' => [
        {
            'Number' => '21B6D76A8B32564B',
            'SubscriptionFile' => [
                {
                    'Delivery' => [
                        {
                            'COD' => {},
                            'Time' => '093300',
                            'TrackingNumber' => '1Z5E33E02210059137',
                            'DeliveryLocation' => {
                                'Code' => 'D2_DLVR_LOC_DESC',
                                'AddressArtifactFormat' => {
                                    'PoliticalDivision2' => 'MOORESTOWN',
                                    'ResidentialAddressIndicator' => {},
                                    'PoliticalDivision1' => 'NJ',
                                    'StreetNumberLow' => '217',
                                    'StreetType' => 'CT',
                                    'StreetName' => 'LAURENCE',
                                    'PostcodePrimaryLow' => '08057',
                                    'CountryCode' => 'US'
                                   },
                                'SignedForByName' => 'DRIVER RELEASE',
                                'Description' => 'FRONT DOOR'
                               },
                            'ActivityLocation' => {
                                'AddressArtifactFormat' => {
                                    'PoliticalDivision2' => 'LAWNSIDE-VINCENTOWN',
                                    'PoliticalDivision1' => 'NJ',
                                    'CountryCode' => 'US'
                                   }
                               },
                            'ShipperNumber' => '5E',
                            'Date' => '20010517'
                           },
                        {
                            'COD' => {},
                            'Time' => '092200',
                            'TrackingNumber' => '1ZF087642210055023',
                            'DeliveryLocation' => {
                                'Code' => 'D2_DLVR_LOC_DESC',
                                'AddressArtifactFormat' => {
                                    'PoliticalDivision2' => 'MCLEAN',
                                    'ResidentialAddressIndicator' => {},
                                    'PoliticalDivision1' => 'VA',
                                    'StreetNumberLow' => '7920',
                                    'StreetType' => 'DR',
                                    'StreetName' => 'JONESBRANCH',
                                    'PostcodePrimaryLow' => '22102',
                                    'CountryCode' => 'US'
                                   },
                                'SignedForByName' => 'TAYLOR',
                                'Description' => 'FRONT DESK'
                               },
                            'ActivityLocation' => {
                                'AddressArtifactFormat' => {
                                    'PoliticalDivision2' => 'DULLES-RESTON',
                                    'PoliticalDivision1' => 'VA',
                                    'CountryCode' => 'US'
                                   }
                               },
                            'ShipperNumber' => 'F0',
                            'Date' => '20010517'
                           },
                       ],
                    'StatusType' => {
                        'Code' => 'U',
                        'Description' => 'Show Unread'
                       },
                    'FileName' => '020208_133243003',
                    'Origin' => {
                        'Time' => '214458',
                        'TrackingNumber' => '1ZV755R90352016311',
                        'ActivityLocation' => {
                            'AddressArtifactFormat' => {
                                'PoliticalDivision2' => 'PHOENIX',
                                'PoliticalDivision1' => 'AZ',
                                'CountryCode' => 'US'
                               }
                           },
                        'ShipperNumber' => 'V7',
                        'Date' => '20010617'
                       }
                   },
                {
                    'Manifest' => [
                        {
                            'Shipper' => {
                                'Address' => {
                                    'PostalCode' => '31098-1887',
                                    'ConsigneeName' => 'WRALC/EGNG',
                                    'AddressLine1' => '450 5TH ST',
                                    'StateProvinceCode' => 'GA',
                                    'City' => 'ROBINS AFB',
                                    'CountryCode' => 'US'
                                   }
                               },
                            'PickupDate' => '20020121',
                            'ScheduledDeliveryDate' => '19000101',
                            'Package' => {
                                'PackageServiceOptions' => {
                                    'COD' => {}
                                   }
                               },
                            'Service' => {
                                'Code' => '007'
                               },
                            'ShipTo' => {
                                'Address' => {
                                    'ConsigneeName' => 'OPERATION SOUTHERN WATCH',
                                    'AddressLine1' => '4404 CWP LGS DSN',
                                    'City' => 'AL KHARJ',
                                    'CountryCode' => 'SA'
                                   }
                               }
                           },
                        {
                            'Shipper' => {
                                'Address' => {
                                    'PostalCode' => '31098-1887',
                                    'ConsigneeName' => 'WRALC/EGNG',
                                    'AddressLine1' => '450 5TH ST',
                                    'StateProvinceCode' => 'GA',
                                    'City' => 'ROBINS AFB',
                                    'CountryCode' => 'US'
                                   }
                               },
                            'PickupDate' => '20020121',
                            'ScheduledDeliveryDate' => '19000101',
                            'Package' => {
                                'PackageServiceOptions' => {
                                    'COD' => {}
                                   }
                               },
                            'Service' => {
                                'Code' => '007'
                               },
                            'ShipTo' => {
                                'Address' => {
                                    'ConsigneeName' => 'BANZ WHSE',
                                    'AddressLine1' => 'SHEIK ISA AIR BASE',
                                    'AddressLine2' => 'DEPLOYED CHIEF OF SUPPLY',
                                    'City' => 'MANAMA',
                                    'CountryCode' => 'BH'
                                   }
                               }
                           },
                       ],
                    'StatusType' => {
                        'Code' => 'U',
                        'Description' => 'Show Unread'
                       },
                    'FileName' => '020211_133241001'
                   }
               ],
            'SubscriptionStatus' => {
                'Code' => 'A',
                'Description' => 'Active'
               },
            'Name' => 'IVS'
           },
        {
            'Number' => '21B6D76A8B32564C',
            'SubscriptionFile' => [
                {
                    'Exception' => {
                        'StatusDescription' => 'ADVERSE WEATHER CONDITIONS DELAY',
                        'Time' => '090000',
                        'TrackingNumber' => '1Z1265180340533017',
                        'ActivityLocation' => {
                            'AddressArtifactFormat' => {
                                'PoliticalDivision2' => 'EL PASO INTL',
                                'PoliticalDivision1' => 'TX',
                                'CountryCode' => 'US'
                               }
                           },
                        'ShipperNumber' => '12',
                        'RescheduledDeliveryDate' => '20011225',
                        'Date' => '20010120'
                       },
                    'Delivery' => [
                        {
                            'COD' => {},
                            'Time' => '041700',
                            'TrackingNumber' => '1Z4381W20314381623',
                            'DeliveryLocation' => {
                                'Code' => 'D2_DLVR_LOC_DESC',
                                'AddressArtifactFormat' => {
                                    'PoliticalDivision2' => 'LOUISVILLE',
                                    'ResidentialAddressIndicator' => {},
                                    'PoliticalDivision1' => 'KY',
                                    'StreetNumberLow' => '2541',
                                    'StreetType' => 'RD',
                                    'StreetName' => 'HOLLOWAY',
                                    'PostcodePrimaryLow' => '40299',
                                    'CountryCode' => 'US'
                                   },
                                'SignedForByName' => 'MONROE',
                                'Description' => 'RECEIVER'
                               },
                            'ActivityLocation' => {
                                'AddressArtifactFormat' => {
                                    'PoliticalDivision2' => 'BLUEGRASS',
                                    'PoliticalDivision1' => 'KY',
                                    'CountryCode' => 'US'
                                   }
                               },
                            'ShipperNumber' => '43',
                            'Date' => '20010517'
                           },
                       ],
                    'Manifest' => [
                        {
                            'Shipper' => {
                                'Address' => {
                                    'PostalCode' => '85226',
                                    'ConsigneeName' => 'INTEL',
                                    'AddressLine1' => '6505 W CHANDLER BLVD',
                                    'StateProvinceCode' => 'AZ',
                                    'City' => 'CHANDLER',
                                    'CountryCode' => 'US'
                                   }
                               },
                            'PickupDate' => '20010118',
                            'ScheduledDeliveryDate' => '20010710',
                            'Package' => {
                                'PackageServiceOptions' => {
                                    'COD' => {}
                                   }
                               },
                            'Service' => {
                                'Code' => '003'
                               },
                            'ShipTo' => {
                                'AttentionName' => 'BOB BRAGDON',
                                'Address' => {
                                    'PostalCode' => '97077',
                                    'ConsigneeName' => 'TEKTRONIX INC.',
                                    'AddressLine1' => 'BOB BRAGDON BLDG #19',
                                    'AddressLine2' => 'HOWARD VOLUME PARK',
                                    'StateProvinceCode' => 'OR',
                                    'City' => 'BEAVERTON',
                                    'CountryCode' => 'US'
                                   }
                               }
                           },
                       ],
                    'StatusType' => {
                        'Code' => 'U',
                        'Description' => 'Show Unread'
                       },
                    'FileName' => '020208_133242002'
                   },
                {
                    'Delivery' => [
                        {
                            'COD' => {},
                            'Time' => '093300',
                            'TrackingNumber' => '1Z5E33E02210059137',
                            'DeliveryLocation' => {
                                'Code' => 'D2_DLVR_LOC_DESC',
                                'AddressArtifactFormat' => {
                                    'PoliticalDivision2' => 'MOORESTOWN',
                                    'ResidentialAddressIndicator' => {},
                                    'PoliticalDivision1' => 'NJ',
                                    'StreetNumberLow' => '217',
                                    'StreetType' => 'CT',
                                    'StreetName' => 'LAURENCE',
                                    'PostcodePrimaryLow' => '08057',
                                    'CountryCode' => 'US'
                                   },
                                'SignedForByName' => 'DRIVER RELEASE',
                                'Description' => 'FRONT DOOR'
                               },
                            'ActivityLocation' => {
                                'AddressArtifactFormat' => {
                                    'PoliticalDivision2' => 'LAWNSIDE-VINCENTOWN',
                                    'PoliticalDivision1' => 'NJ',
                                    'CountryCode' => 'US'
                                   }
                               },
                            'ShipperNumber' => '5E',
                            'Date' => '20010517'
                           },
                       ],
                    'StatusType' => {
                        'Code' => 'U',
                        'Description' => 'Show Unread'
                       },
                    'FileName' => '020208_133244004',
                    'Origin' => {
                        'Time' => '214458',
                        'TrackingNumber' => '1ZV755R90352016311',
                        'ActivityLocation' => {
                            'AddressArtifactFormat' => {
                                'PoliticalDivision2' => 'PHOENIX',
                                'PoliticalDivision1' => 'AZ',
                                'CountryCode' => 'US'
                               }
                           },
                        'ShipperNumber' => 'V7',
                        'Date' => '20010617'
                       }
                   }
               ],
            'SubscriptionStatus' => {
                'Code' => 'A',
                'Description' => 'Active'
               },
            'Name' => 'OVS'
           }
       ],
    'SubscriberID' => 'xxxx'
   };

=cut


sub qv_section {
    my $self = shift;
    my $data = $self->parsed_data;
    if (exists $data->{QuantumViewEvents}) {
        return $data->{QuantumViewEvents};
    }
    else {
        return;
    }
}

=head3 bookmark

Bookmarks the file for next retrieval, It is a base64Encoded String.
It contains the combination of SubscriberID + SubscriptionName + File
Name if the request is for all data. It contains SubscriberID if the
request is for unread data. When a response comes back with a bookmark
it indicates that there is more data. To fetch the remaining data, the
requester should come back with the bookmark added to the original
request.

Sadly enough, the testing endpoint doesn't return any bookmark, so
this is pretty much untested, but it should work.

When you have a bookmark, to get the rest of the data you need to
reissue the request passing the resulting string to the QV fetching.

TODO: Tweak the QV module to handle the bookmarks gracefully.

=cut


sub bookmark {
    my $self = shift;
    my $data = $self->parsed_data;
    if ((exists $data->{Bookmark}) and $data->{Bookmark}) {
        return $data->{Bookmark};
    }
    else {
        return;
    }
}


1;
