package Net::Cisco::FMC::v1::Role::ObjectMethods;

# ABSTRACT: Role for Cisco Firepower Management Center (FMC) API version 1 method generation

use 5.024;
use feature 'signatures';
use MooX::Role::Parameterized;
use Carp;
use Clone qw( clone );
use Moo::Role; # last for cleanup

no warnings "experimental::signatures";

=head1 SYNOPSIS

    package Net::Cisco::FMC::v1;
    use Moo;
    use Net::Cisco::FMC::v1::Role::ObjectMethods;

    Net::Cisco::FMC::v1::Role::ObjectMethods->apply([
        {
            path     => 'object',
            object   => 'portobjectgroups',
            singular => 'portobjectgroup',
        },
        {
            path     => 'object',
            object   => 'protocolportobjects',
            singular => 'protocolportobject',
        }
    ]);

    1;

=head1 DESCRIPTION

This role adds methods for the REST methods of a specific object named.

=cut

=method create_$singular

Takes a hashref of attributes.

Returns the created object as hashref.

Throws an exception on error.

=cut

=method list_$object

Takes optional query parameters.

Returns a hashref with a single key 'items' that has a list of hashrefs
similar to the FMC API.

Throws an exception on error.

As the API only allows fetching 1000 objects at a time it works around that by
making multiple API calls.

=cut

=method get_$singular

Takes an object id and optional query parameters.

Returns the object as hashref.

Throws an exception on error.

=cut

=method update_$singular

Takes an object and a hashref of attributes.

Returns the updated object as hashref.

Throws an exception on error.

=cut

=method delete_$singular

Takes an object id.

Returns true on success.

Throws an exception on error.

=cut

=method find_$singular

Takes query parameters.

Returns the object as hashref on success.

Throws an exception on error.

As there is no API for searching by all attributes this method emulates this
by fetching all objects using the L<list_$object> method and performing the
search on the client.

=cut

role {
    my $params = shift;
    my $mop    = shift;

    $mop->method('create_' . $params->{singular} => sub ($self, $object_data) {
        my $res = $self->post(join('/', '/api/fmc_config/v1/domain', $self->domain_uuid, $params->{path}, $params->{object}), $object_data);
        my $code = $res->code;
        my $data = $res->data;
        croak($data->{error}->{messages}[0]->{description})
            unless $code == 201;
        return $data;
    });

    $mop->method('list_' . $params->{object} => sub ($self, $query_params = {}) {
        # the API only allows 1000 objects at a time
        # work around that by making multiple API calls
        my $offset = 0;
        my $limit = 1000;
        my $more_data_available = 1;
        my @items;
        while ($more_data_available) {
            my $res = $self->get(join('/', '/api/fmc_config/v1/domain', $self->domain_uuid, $params->{path}, $params->{object}),
                { offset => $offset, limit => $limit, %$query_params });
            my $code = $res->code;
            my $data = $res->data;

            croak($data->{error}->{messages}[0]->{description})
                unless $code == 200;

            push @items, $data->{items}->@*
                if exists $data->{items} && ref $data->{items} eq 'ARRAY';

            # check if more data is available
            if ($offset + $limit < $data->{paging}->{count}) {
                $more_data_available = 1;
                $offset += $limit;
            }
            else {
                $more_data_available = 0;
            }
        }

        # return response similar to FMC API
        return { items => \@items };
    });

    $mop->method('get_' . $params->{singular} => sub ($self, $id, $query_params = {}) {
        my $res = $self->get(join('/', '/api/fmc_config/v1/domain',
                $self->domain_uuid, $params->{path}, $params->{object}, $id), $query_params);
        my $code = $res->code;
        my $data = $res->data;

        croak($data->{error}->{messages}[0]->{description})
            unless $code == 200;

        return $data;
    });

    $mop->method('update_' . $params->{singular} => sub ($self, $object, $object_data) {
        my $id = $object->{id};
        my $updated_data = clone($object);
        delete $updated_data->{links};
        delete $updated_data->{metadata};
        $updated_data = { %$updated_data, %$object_data };

        my $res = $self->put(join('/', '/api/fmc_config/v1/domain', $self->domain_uuid, $params->{path}, $params->{object}, $id),
            $updated_data);
        my $code = $res->code;
        my $data = $res->data;
        my $errmsg = ref $data eq 'HASH'
            ? $data->{error}->{messages}[0]->{description}
            : $data;
        croak($errmsg)
            unless $code == 200;
        return $data;
    });

    $mop->method('delete_' . $params->{singular} => sub ($self, $id) {
        my $res = $self->delete(join('/', '/api/fmc_config/v1/domain', $self->domain_uuid, $params->{path}, $params->{object}, $id));
        croak($res->data->{error}->{messages}[0]->{description})
            unless $res->code == 200;
        return 1;
    });

    $mop->method('find_' . $params->{singular} => sub ($self, $query_params = {}) {
        my $listname = 'list_' . $params->{object};
        for my $object ($self->$listname({ expanded => 'true' })->{items}->@*) {
            my $identical = 1;
            for my $key (keys $query_params->%*) {
                if ($object->{$key} ne $query_params->{$key}) {
                    $identical = 0;
                    last;
                }
            }
            if ($identical) {
                return $object;
            }
        }
        croak "object not found";
    });
};

1;
