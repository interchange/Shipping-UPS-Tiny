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


1;

                          
