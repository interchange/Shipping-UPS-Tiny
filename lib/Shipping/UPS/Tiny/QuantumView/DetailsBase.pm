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

# generic internal accessor at root level. Useful for things we may
# want to access but don't care too much to provide a proper accessor
# for.

sub _unrolled_details {
    my ($self, $field) = @_;
    my $data= $self->data;
    return unless $data;
    if (exists $data->{$field}) {
        return $data->{$field};        
    }
    else {
        return;
    }
}

=item tracking_number

The tracking number

=cut

sub tracking_number {
    my $self = shift;
    return $self->_unrolled_details("TrackingNumber") || "";
}

sub _ups_date_to_iso_8601_date {
    my ($self, $date) = @_;
    return "" unless $date;
    if ($date =~ m/([0-9]{4})([0-9]{2})([0-9]{2})/) {
        return "$1-$2-$3";
    }
    else {
        return "";
    }
}

sub _ups_time_to_iso_8601_time {
    my ($self, $time) = @_;
    return unless defined $time;
    my $default = "00:00:00";
    if ($time =~ m/([0-9]{2})([0-9]{2})([0-9]{2})/) {
        return "$1:$2:$3";
    }
    else {
        return $default;
    }
}

sub _ups_datetime_to_iso8601 {
    my ($self, $date, $time) = @_;
    $date = $self->_ups_date_to_iso_8601_date($date);
    $time = $self->_ups_time_to_iso_8601_time($time || "n/a");
    return join(" ", $date, $time);
}

sub _get_ref_nums {
    my $self = shift;
    my $refs = $self->_unrolled_details("ReferenceNumber");
    my @list;
    if ($refs) {
        foreach my $ref (@$refs) {
            push @list, $ref->{Value};
        }
    }
    # if not present, we try to return the parent data.
    return @list;
}

=item pickup_date

Returns undef (overloaded by the Manifest's Package).

=cut

sub pickup_date {
    return undef;
}

=item details

Returns the empty string (to be overloaded).

=items scheduled_delivery_date

=cut

sub details {
    return "";
}

sub scheduled_delivery_date {
    return undef;
}


=item shared_methods

List of the methods shared between Delivery, Package (from Manifest)
and Exception. These methods define the data which can be stored in
the database in a common table.

=cut

sub shared_methods {
    return (qw/subscription_number subscription_name subscription_status
               subscription_status_desc file_status_desc
               file_status file_name
               source
               tracking_number
               reference_number
               latest_activity
               activity_location
               scheduled_delivery_date
               destination
               details
               pickup_date/);
}

1;

                          
