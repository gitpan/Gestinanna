package Gestinanna::ContentProvider::XSM;

use base qw(Gestinanna::ContentProvider);

use Data::UUID;
use File::Path;
use File::Spec;
use Gestinanna::Request;
use Gestinanna::XSM;
use Gestinanna::XSM::Auth;
use Gestinanna::XSM::Authz;
use Gestinanna::XSM::Base;
use Gestinanna::XSM::ContentProvider;
use Gestinanna::XSM::Diff;
use Gestinanna::XSM::Digest;
use Gestinanna::XSM::Gestinanna;
use Gestinanna::XSM::POF;
use Gestinanna::XSM::SMTP;
use Gestinanna::XSM::XMLSimple;
#use YAML ();
use Storable ();

use strict;
no strict 'refs';

sub config {
    my($class, $config) = @_;

# load taglib classes here
    foreach my $taglib (@{$config -> {taglib}||[]}) {
        eval "require $taglib;";
        if($@) {
            warn "Unable to load $taglib: $@\n";
        }
        else {
            warn "   [XSM - Loaded $taglib]\n";
        }
    }
}


sub compile {
    my($self, $cache_dir, $pkg_root, $filename) = @_;
#    use Data::Dumper;
#    warn "Info: " . Data::Dumper -> Dump([\%info]);

    my $R = Gestinanna::Request -> instance;

    my $content = $self -> retrieve_content( $filename );
    return undef unless $self -> is_content_good( $content );
    my $f = $filename;
    $f =~ s{/}{::}g;
    $f =~ s{[^a-zA-Z0-9:]+}{_}g;
    my $v = $content -> revision;
    $v =~ tr[.][_];
    my $sm_class = "${pkg_root}${f}::v${v}";

    my $compiler = sub {
        my($filename) = shift;
        #warn "Compiling $filename\n";
        $self -> compile(
            $cache_dir, 
            $pkg_root, 
            $filename,
        );
    };
     
    #warn "Class: $sm_class\n";
    unless($sm_class -> VERSION) {
        # check file cache
        my $cache_file = File::Spec -> catfile($cache_dir,$filename, "v$v");
        if(-e $cache_file && -r _) {
            eval { require "$cache_file"; };
            if($@) {
                warn "Unable to load cached version of $filename $v: $@\n";
                my $code = Gestinanna::XSM -> compile($content -> data, compiler => $compiler, factory => $R -> factory);
                #warn "Code: package $sm_class; $code";
                eval "package $sm_class;\n\nuse strict;\n\n$code;\n1;";
                if($@) {
                    warn "Code:\npackage $sm_class;\n\nuse strict;\n\n$code;\n1;\n ___END___ # code\n";
                    warn "\n\n$@\n\n";
                    return $R -> error(
                        error => 'internal.compile.xsm',
                        args => { uri => $self -> {filename},
                                  class => $sm_class,
                                  message => $@,
                                },
                    );
                }
            }
        }
        else {
            my $code = Gestinanna::XSM -> compile($content -> data, compiler => $compiler, factory => $R -> factory);
            $code .= "our \$FILENAME = \"\Q$filename\E\";\n";
            my $dv = $content -> revision;
            $code .= "our \$VERSION = \"\Q$dv\E\";\n";
            #warn "Code: package $sm_class; $code";
            eval "package $sm_class;\n\nuse strict;\n\n$code;\n1;";
            if($@) {
                    warn "Code:\npackage $sm_class;\n\nuse strict;\n\n$code;\n1;\n ___END___ # code\n";
                warn "\n\n$@\n\n";
                return $R -> error(
                    error => 'internal.compile.xsm',
                    args => { uri => $self -> {filename},
                              class => $sm_class,
                              message => $@,
                            },
                );
            }
            #else {  # for debugging purposes
                my $cache_file = "$cache_dir$filename/v$v";
                eval { File::Path::mkpath("$cache_dir$filename"); };
                if($@) {
                    warn "Unable to create cache directories for $filename: $@\n";
                }
                elsif(open my $fh, ">", $cache_file) {
                    print $fh "package $sm_class;\n\nuse strict;\n\n$code;\n1;";
                    close $fh;
                }
                else {
                    warn "Unable to open $cache_file to save $filename $v: $!\n";
                }
            #}
        }
        #${"${sm_class}::FILENAME"} = $filename;
        #${"${sm_class}::VERSION"} = $content -> revision;
    }
    foreach my $file (@{"${sm_class}::FILES"}) {
        #warn "Loading ${cache_dir}${file}\n";
        eval { require ${cache_dir} . ${file};};
        warn "$@\n" if $@;
    }
    return $sm_class;
}

sub may_exec { 1; } # for now

sub init {
    my($class, %info) = @_;

    #my $self = $class -> SUPER::init(%info);
    my $R = Gestinanna::Request -> instance;

    # we want to go through this until we don't call any statemachines
    my $self = bless { %info } => $class;

    my $pkg_root = $info{config} -> {package} || $R -> config -> {package} . "::XSM";
    my $filename = $info{filename};

    #warn "file: $filename\n    pkg_root: $pkg_root\n";

    #warn "args: ", Data::Dumper -> Dump([$self -> {args}]);

    my $context = $self -> get_context;
    my $sm;
    my($view, $args);

    # TODO: make cache_dir configurable
    my $cache_dir = $info{config} -> {cache} -> {dir};

    my $content;
    my $goto_state;
    my $caught_goto = 0;
    $filename = $self -> {filename}; # jic it was changed by the context
    while($filename) {
        #warn "filename: $filename\n";
        #warn "goto_state: " . Data::Dumper -> Dump([$goto_state]);
        #if($filename ne $content -> name) { # load $filename
        #    $content = $info{axkit_cp} -> factory -> new( $self->{type}, object_id => $filename );
        #}
        #warn "Content of $filename: [" . $content -> data . "]\n";
        my $sm_class = $self -> compile($cache_dir, $pkg_root, $filename);
        return $sm_class if ref $sm_class;# error page returned
        warn "No class returned\n" and last unless defined $sm_class;

            

        my($ostate);

        if(!$goto_state && $context) {
            #warn "context and no goto_state\n";
            $sm = $sm_class -> new( context => $context, _factory => $R->factory );
            $ostate = $sm -> state;
            #$sm -> state($ostate); # jic the state is from a goto and it's aliased
        }
        else {
            #warn "goto_state or no context\n";
            no strict 'refs';
            #warn "\@${sm_class}::ISA: " . join(", ", @{"${sm_class}::ISA"}) . "\n";
            $sm = $sm_class -> new(_factory => $R->factory);
            $sm -> state($ostate = '_begin');
            #local $Gestinanna::ContentProvider::XSM::AxKitProvider = $R;
            if($sm -> can('initialize')) {
                $sm -> clear_data('in');
                $sm -> clear_data('messages');
                $sm -> add_data('in', $self -> {args});
                my $state;
                eval {
                    $state = $sm -> initialize if $sm -> can('initialize');
                };
                #warn "caught $@ after initialize\n";
                if($@ && ref $@) {
                    my $e = $@;
                    if($e -> op eq 'goto') {
                        #warn "Caught a `goto'\n";
                        if(defined $e -> arg('filename')) {
                            #warn "filename: " . $e -> arg('filename') . "\n";
                            #warn "state: " . $e -> arg('state') . "\n";
                            $self -> set_context($sm -> context);
                            #my $c = YAML::Dump({
                                #state => $e -> arg('state') || '_begin',
                                #saved_context => $self -> {_context_id},
                            #});
                            $context = undef; #$c;
                            $goto_state = { next_state => $e -> arg('next-state'), state => $e -> arg('state'), prev_filename => $filename, args => $e -> arg('args')||{} };
                            $filename = $e -> arg('filename');
                            next;
                        }
                        elsif($e -> arg('state') ne '') { # no filename - just a regular goto
                            $state = $e -> arg('state');
                        }
                    }
                    else {
                        die $e; # rethrow
                    }
                }
                else {
                    die $@ if $@;
                }
                if(defined $state && $state ne '') {
                    $sm -> transit($state);
                    $sm -> state($state);
                }
            }
            if(defined $goto_state) {
                $caught_goto = 1;
                $sm -> {context} -> {prev}{context} = $self -> {_context_id};
                $sm -> {context} -> {prev}{filename} = $goto_state -> {prev_filename};
                $sm -> {context} -> {prev}{state} = $goto_state -> {prev_state} if $goto_state -> {prev_state};
                $sm -> {context} -> {prev}{next_state} = $goto_state -> {next_state};
                #warn "We are goto'ing to state: [" . $goto_state->{state} . "]\n";
                $sm -> {context} -> {data} -> {out} = $goto_state -> {args} || {}; # pass in info from calling state machine
                if(defined $goto_state->{state} && $goto_state -> {state} ne '') {
                    eval { $sm -> initialize if $sm -> can('initialize'); };
                    $sm -> transit($goto_state -> {state});
                    $sm -> state($goto_state -> {state});
                }
                else {
                    $sm -> state('_begin');
                }
                $self -> {filename} = $filename; # for context
            }
        }

        if(!$goto_state) {
        #local $Gestinanna::ContentProvider::XSM::AxKitProvider = $R;
        $ostate = $sm -> state;
        #warn "Old state: $ostate\n";
        eval { $sm -> process($self -> {args}); } if keys %{$self -> {args} || {}}; # && $context
        if($@ && UNIVERSAL::isa($@, 'Gestinanna::XSM::Op')) {
            my $e = $@;
            if($e -> op eq 'goto') {
                #warn "Caught a `goto'\n";
                if(defined $e -> arg('filename')) {
                    #warn "filename: " . $e -> arg('filename') . "\n";
                    #warn "state: " . $e -> arg('state') . "\n";
                    $self -> set_context($sm -> context);
                    #my $c = YAML::Dump({
                        #state => $e -> arg('state') || '_begin',
                        #saved_context => $self -> {_context_id},
                    #});
                    $context = undef; #$c;
                    $goto_state = { prev_state => $ostate, next_state => $e -> arg('next-state'), state => $e -> arg('state'), prev_filename => $filename, args => $e -> arg('args')||{} };
                    $filename = $e -> arg('filename');
                    next;
                }
                else { # no filename - just a regular goto
                }
            }
            elsif($e -> op eq 'startover') { # fundamental stuff
                #warn "Caught startover\n";
                $self -> set_context($sm -> context); # go ahead and save this
                $e -> {arg}{contexts}{''} = $self -> {_context_id};
                $e -> throw; # rethrow
            }
            else {
                $e -> throw; # rethrow
            }
        }
        elsif($@) {
            # error...
            warn "Error: $@\n Going to _debug...\n";
            $args = $sm -> data();
            $args -> {_error} = $@;
            $args -> {_debug_log} = $sm -> log;
            $view = "_debug";
        }
        else {
            $args = $sm -> data();
            $view = $sm -> view;
        }
        }
        else {
            $args = $sm -> data();
            $view = $sm -> view;
        }

        #warn "Args: " . Data::Dumper -> Dump([$args]);

        #warn "View: $view\n";

        # need to save context
        if($sm -> is_not_terminal_state($sm -> state)) {
            $self -> set_context($sm -> context)
                if $sm -> transitioned || $caught_goto;
            $filename = undef;
        }
        else {
            $context = $sm -> context;
            my $id = $self -> {_context_id};
            my $c = Storable::thaw($context);
            while(!$sm -> is_not_terminal_state($sm -> state) && $c -> {prev}{filename}) {
                #warn "Working with context: " . Data::Dumper -> Dump([$c]);
                $filename = $c -> {prev}{filename};
                $sm_class = $self -> compile($cache_dir, $pkg_root, $filename);
                return $sm_class if ref $sm_class;# error page returned
                $self -> {_context_id} = $c -> {prev}{context};
                $context = $self -> get_context;
                #warn "Returning to context: " . Data::Dumper -> Dump([Storable::thaw($context)]);
                $sm = $sm_class -> new( context => $context, _factory => $R->factory );
                if($c -> {prev}{next_state}) {
                    $sm -> state($c -> {prev}{state} eq $c -> {prev}{next_state} ? undef : $c -> {prev}{state});
                    #warn "Running transition from ", $sm -> state, " to ", $c -> {prev}{next_state}, "\n";
                    $sm -> transit($c -> {prev}{next_state});
                    $sm -> state($c -> {prev}{next_state});
                }
                else {
                    $sm -> state(undef);
                    #warn "Running transition from <undef> to ", $c -> {prev}{state}, "\n";
                    $sm -> transit(undef, $c -> {prev}{state});
                    $sm -> state($c -> {prev}{state});
                }
                $c = Storable::thaw($context);
                #warn "Next context: " . Data::Dumper -> Dump([$c]);
            }
            $args = $sm -> data();
            $view = $sm -> view;
            $filename = undef;
            $self -> {_context_id} = $id; # make the parent of the next one the one we just returned from
            $self -> set_context($sm -> context)
        }
    }

    #return $sm -> view;
    # we need to return a content provider for the view

    #warn "filename: $$self{filename}\n";
    #warn "view: $view\n";

    # really need to follow the inheritance chain of the state, which may go through a %HASA entry
    my @classes = grep { defined } ((ref $sm || $sm), map { $_ -> [0] } $sm -> get_super_path($sm -> state));
    push @classes, Class::ISA::super_path($_) for @{[@classes]}; # make copy of @classes first so we don't spin
    warn "classes: ", join("; ", @classes), "\n";
    my @path = map { ($_ -> filename) } grep { UNIVERSAL::can($_, 'filename') } @classes;

    #warn "Superpath for " . $sm -> state . ": ", join(", ", $sm -> get_super_path($sm -> state)), "\n";
    warn "file paths: ", join("; ", @path), "\n";

    #my @views = ($filename);

    foreach my $p (@path) {
        #warn "Trying $p/$view\n";
        my $cp = $R -> get_content_provider(
            args => $args,
            filename => "$p/$view",
            type => $info{config} -> {'view-type'},
            include_path => \@path,
        );
        if($cp) {
            $self -> {_content_provider} = $cp;
            $self -> {_args} = $args;
            #Carp::cluck "Returning $p/$view\n";
            return $self;
        }
    }

    return $R -> error(
        error => 'not-found.view.xsm',
        args => { uri => $info{filename},
                  state => $sm -> state,
                  view => $view,
                },
    );
}

sub content {
    my $self = shift;

    my $content = $self -> dom -> toString(0);

    return \$content;
}

sub dom {
    my $self = shift;

    #warn "Content provider: $$self{_content_provider}\n";
    my $dom = $self -> {dom} ||= $self -> {_content_provider} -> dom;
    my $parser = XML::LibXML -> new;
    #$parser -> expand_entities(0);

    #warn "dom: $dom\ncontent provider: $$self{_content_provider}\n";

    # find top-level <form/> and insert <hidden/> field for context id
    my $root = eval { $dom -> documentElement; };
    if($@) {
        warn "$@\n";
        return $dom;
    }

    if(defined $self -> {_context_id}) {
        my $context_id_el = $parser -> parse_xml_chunk("<stored id='_context_id'><value>" . $self -> {_context_id} . "</value></stored>");

        my $forms = $dom -> findnodes('//form[count(ancestor::form) = 0]');
        foreach my $form ($forms -> get_nodelist) {
            # need to ensure that this is the first form with no parent form element
            $form -> appendChild($context_id_el);
            #last;
        }
    }

    my $args = $self -> {_args} || {};

    # go through and set defaults/missing for elements
    my $form_elements = $dom -> findnodes('
        //text
        | //textline
        | //textbox
        | //editbox
        | //file
        | //password
        | //selection
        | //grid
    ');

    foreach my $e ($form_elements -> get_nodelist) {
        my $default;
        my $is_grid = 0;
        if($e -> localName eq 'grid') {
            $default = $e -> findnodes('./default | ./row/default | ./column/default');
            $is_grid = 1;
        }
        else {
            $default = $e -> findnodes('./default');
        }
        my $missing = $e -> getAttribute('missing');
        my $own_id = $e -> getAttribute('id');
        #warn "Own id: $own_id\n";
        next unless defined $own_id;
        my $ancestors = $e -> findnodes(q{
            ancestor::option[@id != '']
            | ancestor::selection[@id != '']
            | ancestor::group[@id != '']
            | ancestor::form[@id != '']
            | ancestor::container[@id != '']
        });
        my @ids = grep { defined } map { $_ -> getAttribute('id') } $ancestors -> get_nodelist;
        push @ids, $own_id;
        next unless @ids;
        my $id = join(".", @ids);
        #warn "Looking at $id\n";
        @ids = split(/\./, $id);
        if(!$default -> get_nodelist) {
            # create a new node 'default'
            # try to find a value in $args -> {out}
            my $l = $args -> {out};
            for (@ids) {
                #warn "Looking for [$_] in " . Data::Dumper -> Dump([$l]);
                $l = (ref $l && exists $l -> {$_}) ? $l -> {$_} : undef;
                last unless defined $l;
            }
            #$l = (ref $l && exists $l -> {$_}) ? $l -> {$_} : last for @ids;
            if($is_grid) {
                if(UNIVERSAL::isa($l, 'HASH') && exists($l -> {'value'}) && UNIVERSAL::isa($l -> {'value'}, 'HASH')) {
                    $l = $l -> {'value'};
                }
                # need to put in defaults based on -by-row -by-column or neither
                my $count = $e -> getAttribute('count');
                my($how_many, $direction) = qw(multiple both);
                if($count =~ m{^(multiple|single)(-by-(row|column))?$}) {
                    $how_many = $1;
                    $direction = $3 || 'both';
                }
                if($direction eq 'both') {
                    # place them as grid/default
                    foreach my $v ( @$l ) {
                        $default = $dom -> createElement('default');
                        my $text = $dom -> createTextNode($v);
                        $default -> addChild($text);
                        $e -> addChild($default);
                    }
                }
                elsif($direction eq 'row' || $direction eq 'column') {
                    # place them as grid/$direction/default
                    my $divs = $e -> findnodes($direction);
                    foreach my $div ($divs -> get_nodelist) {
                        my $id = $div -> getAttribute('id');
                        my $ll;
                        if(UNIVERSAL::isa($l, 'ARRAY')) {
                            $ll = [ map { $_ =~ m{\.(.*)$} && $1 } grep { m{^\Q$id\E\..} } @$l ];
                        }
                        elsif(UNIVERSAL::isa($l, 'HASH') && exists $l -> { $id } && UNIVERSAL::isa($l -> {$id}, 'ARRAY')) {
                            $ll = $l -> { $id };
                        }
                        foreach my $v (@{$ll || []}) {
                            $default = $dom -> createElement('default');
                            my $text = $dom -> createTextNode($v);
                            $default -> addChild($text);
                            $div -> addChild($default);
                        }
                    }
                }
            }
            else {
                $l = $l -> {value} if UNIVERSAL::isa($l, 'HASH') && exists($l -> {'value'});
                if(defined $l) {
                    #warn "Setting default for [$id] to [$l].\n";
                    $l = [ $l ] unless UNIVERSAL::isa($l, 'ARRAY');
                    foreach my $v ( @$l ) {
                        $default = $dom -> createElement('default');
                        my $text = $dom -> createTextNode($v);
                        $default -> addChild($text);
                        $e -> addChild($default);
                    }
                }
            }
        }
        if(!defined $missing) {
        #    my $id = join(".", @ids);
            if($args -> {missing} -> {$id}) {
                #warn "Setting [$id] to missing.\n";
                $missing = $dom -> createAttribute('missing', 1);
                $e -> addChild($missing);
            }
            else {
                my $l = $args -> {missing};
                #$l = (ref($l) && exists $l -> {$_}) ? $l -> {$_} : last for @ids;
                for (@ids) {
                    #warn "Looking for [$_] in " . Data::Dumper -> Dump([$l]);
                    $l = (ref $l && exists $l -> {$_}) ? $l -> {$_} : undef;
                    last unless defined $l;
                }
                $l = $l -> {value} if UNIVERSAL::isa($l, 'HASH') && exists($l -> {'value'});
                if($l) {
                    #warn "Setting [$id] to missing.\n";
                    $missing = $dom -> createAttribute('missing', 1);
                    $e -> addChild($missing);
                }
            }
        }
    }

    return $dom;
}

sub get_context {
    my($self) = @_;

    #warn "$self -> get_context\n";
    return unless defined $self -> {config} -> {'context-type'};

    my $R = Gestinanna::Request -> instance;

    my $id;
    if($self -> {args} -> {_context_id}) {
        $id = delete $self -> {args} -> {_context_id};
        $self -> {_context_id} = $id;
    }
    else {
        $id = $self -> {_context_id};
    }

    return unless defined $id;

    my $context = $R -> factory -> new($self -> {config} -> {'context-type'} => object_id => $id);

    #warn "Loading context $id  filename: ", $context -> filename, "\n";

    if($context -> filename ne $self -> {filename}) {
        $self -> {filename} = $context -> filename; # probably want some other logic here
    }

    return $context -> context;
}

sub set_context {
    my($self, $data) = @_;

    return unless defined $self -> {config} -> {'context-type'};

    my $R = Gestinanna::Request -> instance;

    my $old_id = $self -> {_context_id};
    $self -> {_uuid} ||= Data::UUID -> new;
    my($id, $context);

    $id = $self -> {_uuid} -> create_str();

    $context = $R -> factory -> new($self -> {config} -> {'context-type'} => object_id => $id);

    while($context -> is_live) {
        $id = $self -> {_uuid} -> create_str();
        $context = $R -> factory -> new($self -> {config} -> {'context-type'} => object_id => $id);
    }

    $self -> {_context_id} = $id;

    $context -> parent($old_id);
    $context -> context($data);
    $context -> filename($self -> {filename});
    $context -> user_id(undef);
    $context -> user_id($R -> factory -> {actor} -> object_id)
        if defined $R -> factory -> {actor};

#    warn "Saving context $id: $data\n";

    $context -> save;
}

sub remove_contexts {
    my($self) = @_;

    # trace back to root context and delete all ancestors of this context that have no children

}

1;

__END__

=head1 NAME

Gestinanna::ContentProvider::XSM - Provides state machines

=head1 SYNOPSIS

 my($machine, $output) = Gestinanna::ContentProvider -> pipeline(
     \%ARGS, \%info,
     'state-machine' => 'Gestinanna::ContentProvider::StateMachine',
 );

In XML (on a portal-like page):

 <box class="state-machine" id="/sys/login"/>

=head1 DESCRIPTION

State machines provide an easy way to write a controller for a 
web application.  They tie the views and the model together and 
track where the client is in the flow.  By using a content 
provider, multiple state machines can be placed on a page.  Only 
the data from the client destined for that state machine is given 
to it.  Because of the way state machines work in Gestinanna, 
they will not get confused or do an action multiple times because 
another state machine is being used on the same page.  For the 
most part, each is given the illusion that they control the entire 
page.

The user interface for state machines allows the client to 
request that a particular state machine take the entire page.  
Thus, a selection of state machines can be placed on a single tab 
in the front page of a portal.  The user can then select one to 
run, or use the state machine entirely embedded in the portal 
page, whichever is most comfortable.
