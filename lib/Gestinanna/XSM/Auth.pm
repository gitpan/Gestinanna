####
# Functions implementing auth:* processing
####

package Gestinanna::XSM::Auth;

use strict;

our @ISA = qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/auth';

__PACKAGE__ -> register;

sub start_document {
    return "#initialize auth namespace\n";
}

sub end_document {
    return '';
}

sub comment {
    return '';
}
        
sub processing_instruction {
    return '';
}
            
sub characters {
    my ($e, $text) = @_;
 
    $e -> append_state('text', $text);

    return '';
}

my %test_types = qw( lt < le <= gt > ge >= eq = ne != );
 
sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);
     
    $tag = $node->{Name};
     
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }

    #else {
        warn("Unrecognised tag: $tag");
    #}

    return '';
}

sub end_element {
    my ($e, $node) = @_;
     
    my($tag, %attribs);

    $tag = $node->{Name};

    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }

    return '';
}

# definitely need to protect this function at some point
sub xsm_set_actor($$) {
    my $sm = shift;

    #return unless $sm -> filename =~ m{^/sys/secure/};
    my ($actor) = shift;

    my $R = Gestinanna::Request -> instance;
    if(defined $actor) {
        return unless $actor && UNIVERSAL::can($actor, 'object_id');
        warn "Actor: $actor - ", $actor -> object_id, "\n";
        $R -> factory -> {actor} = $actor;
        $R -> session -> {actor_id} = $actor -> object_id;
    } else {
        # actually, need to make this the guest
        warn "logging out...\n";
        delete $R -> session -> {actor_id};
        delete $R -> factory -> {actor};
        my $ctx = $R -> session -> {contexts} || {};
        delete @{$ctx}{grep { m{^_embedded(\._embedded)*$} } keys %$ctx};
    }
    Gestinanna::XSM::Op -> startover(
        reset_embedded_ctx => 1,
    );
}

sub xsm_encode_password($$) {
    my $sm = shift;
    my $password = shift;

    require Digest::MD5;
    return Digest::MD5::md5_hex(Digest::MD5::md5_hex($password) . $password);
}

sub valid_authentic {
    my( $password, $username ) = @_;

    my $R = Gestinanna::Request -> instance;
    warn "username: $username\n";
    my $unameob = $R -> factory -> new(username => object_id => $username);
    warn "username ob: $unameob; is_live: " . $unameob -> is_live . "\n";
    return 0 unless $unameob && $unameob -> is_live;
    my $userob = $R -> factory -> new(user => object_id => $unameob -> user_id);
    warn "user ob: $userob; is_live: " . $userob -> is_live . "\n";
    return 0 unless $userob && $userob -> is_live;
    warn "encoded password: " . xsm_encode_password(undef, $password) . "\nstored password: " . $userob -> password . "\n";
    return $userob -> compare('password', xsm_encode_password(undef, $password));
}

sub valid_username {
    my( $username ) = @_;

    return 0 unless defined $username;
    return 0 unless $username =~ m{^[a-z][-a-z0-9_.]*[a-z0-9]$};
    return 1;
}

sub valid_password {
    my( $password ) = @_;

#    Carp::cluck "password: $password\n";
    return 0 unless defined $password;
    return 0 unless $password =~ m{[a-zA-Z]};
    return 0 unless $password =~ m{[0-9]};
    return 0 unless length($password) > 5;
    return 1;
}

1;
