package Gestinanna::ContentProvider::Portal;

use base qw(Gestinanna::ContentProvider);

use Data::UUID;

sub config {
    my($class, $config) = @_;
}

sub init {
    my($class, %info) = @_;

    my $self = $class -> SUPER::init(%info);
    my $R = Gestinanna::Request -> instance;

    #warn "initialized " . __PACKAGE__ . " object: $self\n";
#    use Data::Dumper;
#    warn "Info: " . Data::Dumper -> Dump([\%info]);

    # we want to use the default page or the user's preference
    my $actor_id =  $R -> session -> {actor_id};
    
    # we want to put portal pages under revision control so customers can undo changes :)
    # but this is limited to undo|redo - no branching
    my $page;
    my $site = $R -> config -> {site};
    my @possibilities;

    # we might want to become more sophisticated, but this should do okay for now 
    #   example: add bits and pieces depending on the state of the user: student, staff, OC, etc.
    if($info{filename}) {
        @possibilities = ( $info{filename} );
    }
    elsif(defined $actor_id) {
            @possibilities = (
            "/user/$actor_id/$site$info{filename}",
            "/user/_default/$site$info{filename}",
            "/user/_default/0$info{filename}",
        );
    }
    else {
        my @possibilities = (
            "/default/$site$info{filename}",
            "/default/0$info{filename}",
        );
    }
    while(@possibilities) {
        my $p = shift @possibilities;
        #warn "Getting $p\n";
        $page = $R -> factory -> new(
            $info{type} => 
                object_id => $p,
                #(defined($actor_id)
                #    ? (tag_path => [ $actor_id, @{$info{factory}->{tag_path}||[]} ])
                #    : ( )
                #),
        );
        #warn "\$page -> is_live: " . $page -> is_live . "\n";
        last if $page -> is_live;
    }

    #return $sm -> view;
    # we need to return a content provider for the view

    return $R -> error(
        error => 'not-found.view.portal',
        args => { uri => $info{filename},
                  actor_id => $actor_id,
                  site => $site,
                },
    ) unless $page -> is_live;

    my $parser = XML::LibXML -> new;
    my $xml = $page -> data;

    $self -> {dom} = $parser -> parse_string($xml);

    #Carp::cluck "Returning $self";

    $self -> dom; # make sure things are initialized and Ops can be thrown at the right time

    return $self;
}

sub content {
    my $self = shift;

    my $content = $self -> dom -> toString(0);

    return \$content;
}

sub dom {
    my $self = shift;

    my $dom = $self -> {dom};

    return $dom if $self -> {_processed_dom};

    my $parser = XML::LibXML -> new;

    # find top-level <form/> and insert <hidden/> field for context id
    my $root = $dom -> documentElement;

    my $boxes = $dom -> findnodes('//container[@uuid]');
    foreach my $box ($boxes -> get_nodelist) {
        # need to ensure that this is the first form with no parent form element
        #$form -> appendChild($context_id_el);
        # need to figure out the type and path, call the content provider and insert the resulting dom in-place
        my $type = $box -> getAttribute('type');
        my $id = $box -> getAttribute('id');
        my $uuid = $box -> getAttribute('uuid'); # used to match up stuff later and pull args out of global args
        #warn "box: type=$type  id=$id  uuid=$uuid\n";
        my $args = {
            map { $_ => $self -> {args} -> {$uuid . ".$_"} }
                map { my $a = $_; $a =~ s{^$uuid\.}{}; $a }
                    grep { m{^$uuid\.} } keys %{$self -> {args} || {}}
        };
        #warn "Args for [$uuid]: ", Data::Dumper -> Dump([$args]);
        my $cp;

        my $R = Gestinanna::Request -> instance;

        eval {
            $cp = $R -> get_content_provider( 
                args => $args,
                filename => $id,
                type => $type,
            );
        };
        if($@ && UNIVERSAL::isa($@, 'Gestinanna::XSM::Op')) {
            my $e = $@;
            if($e -> op eq 'startover') { # promote context specs
                my %ctx;
                foreach my $c (keys %{$e -> {arg}{contexts} || {}}) {
                    if($c ne '') {
                        $ctx{$uuid . ".$c"} = $e -> {arg}{contexts}{$c};
                    }
                    else {
                        $ctx{$uuid} = $e -> {arg}{contexts}{$c};
                    }
                }
                $e -> {arg}{contexts} = \%ctx;
            }
            $@ -> throw; # rethrow
        }
        else {
            warn "$@\n";
        }
        if($cp) {
            my $boxdom = $cp -> dom;
            my $boxroot = $boxdom -> documentElement;
            $boxroot -> setAttribute(id => $uuid); # for form elements :)
            $dom -> adoptNode( $boxroot );
            $box -> replaceNode( $boxroot );
        }
    }

    $self -> {_processed_dom} = 1;

    return $dom;
}

1;

__END__

=head1 NAME

Gestinanna::ContentProvider::Portal - Provides portal-like pages

=head1 SYNOPSIS
