package Net::Cisco::FMC::v1::Role::ObjectMethods;

# ABSTRACT: Role for Cisco Firepower Management Center (FMC) API version 1 method generation

use 5.024;
use feature 'signatures';
use MooX::Role::Parameterized;
use Carp;
use Clone qw( clone );
use Moo::Role; # last for cleanup

no warnings "experimental::signatures";

requires qw( _create _list _get _update _delete );

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
        return $self->_create(join('/',
            '/api/fmc_config/v1/domain',
            $self->domain_uuid,
            $params->{path},
            $params->{object}
        ), $object_data);
    });

    $mop->method('list_' . $params->{object} => sub ($self, $query_params = {}) {
        return $self->_list(join('/',
            '/api/fmc_config/v1/domain',
            $self->domain_uuid,
            $params->{path},
            $params->{object}
        ), $query_params);
    });

    $mop->method('get_' . $params->{singular} => sub ($self, $id, $query_params = {}) {
        return $self->_get(join('/',
            '/api/fmc_config/v1/domain',
            $self->domain_uuid,
            $params->{path},
            $params->{object},
            $id
        ), $query_params);
    });

    $mop->method('update_' . $params->{singular} => sub ($self, $object, $object_data) {
        my $id = $object->{id};
        return $self->_update(join('/',
            '/api/fmc_config/v1/domain',
            $self->domain_uuid,
            $params->{path},
            $params->{object},
            $id
        ), $object, $object_data);
    });

    $mop->method('delete_' . $params->{singular} => sub ($self, $id) {
        return $self->_delete(join('/',
            '/api/fmc_config/v1/domain',
            $self->domain_uuid,
            $params->{path},
            $params->{object},
            $id
        ));
    });

    $mop->method('find_' . $params->{singular} => sub ($self, $query_params = {}) {
        my $listname = 'list_' . $params->{object};
        for my $object ($self->$listname({ expanded => 'true' })->{items}->@*) {
            my $identical = 1;
            for my $key (keys $query_params->%*) {
                if ( ref $query_params->{$key} eq 'Regexp') {
                    if ($object->{$key} !~ $query_params->{$key}) {
                        $identical = 0;
                        last;
                    }
                }
                else {
                    if ($object->{$key} ne $query_params->{$key}) {
                        $identical = 0;
                        last;
                    }
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
