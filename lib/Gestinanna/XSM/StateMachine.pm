####
# Functions implementing sm:* processing
####

package Gestinanna::XSM::StateMachine;

our @ISA = qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/statemachine';

#__PACKAGE__ -> register;

sub start_document {
    return "#initialize sm namespace\nuse Gestinanna::Request;\n";
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

    if($e -> state('in-text')) {
        return "\"\Q$text\E\"";
    }
    $e -> append_state('text', $text);

    return '';
}

sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);

    $tag = $node->{Name};
    
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }

    if ($tag eq 'statemachine') {
        # need to store the package name
        # go ahead and put the package here
        if($attribs{inherit}) {
            $e -> {SM_EDGES} -> {_INHERIT} = $e -> makeSingleQuoted($attribs{inherit});
        }
        return '';
    }
    elsif ($tag eq 'inherit') {
        #warn qq{<inherit name="$attribs{name}" class="$attribs{class}" id="$attribs{id}"/>\n};
        my $class;
        if($attribs{class}) {
            eval "require \Q$attribs{class}\E;";
            if($@) {
                warn "Unable to load $attribs{class}\n";
            }
            else {
                $class = $attribs{class};
            }
        }
        elsif($attribs{name}) {
            # compile file and push resulting package into SM_HASA
            my @path = map { s{/[^/]+$}{/}; $_ } ( 
                $e -> {filename}
            );  # basically, current package filename
            foreach my $p (@path) {
                $class = $e->{compiler} -> (File::Spec::Unix -> rel2abs($attribs{name}, $p));
                last unless ref $class;
            }
            if(ref $class) {
                warn "Unable to compile $attribs{name}\n";
                return '';
            }
            #$class = $attribs{name}; # for later
        }

        #warn "Compiled $attribs{name} into $class\n";

        return '' unless defined $class;
        if($attribs{id}) {
            $e -> {SM_HASA} -> {$attribs{id}} = $class;
        }
        else {
            push @{$e -> {SM_ISA}||=[]}, $class;
        }
        if($class =~ m{::(v\d+(_\d+)*)$}) {
            #push @{$e -> {SM_FILES}||=[]}, $attribs{name} . "/$1";
            push @{$e -> {SM_FILES}||=[]}, join('/', $class -> filename, $1);
        }
        return '';
    }
    elsif ($tag eq 'alias') {
        return '' if $e -> state('in-script');
        $e -> {SM_ALIASES} -> {$e -> makeSingleQuoted($attribs{id})} = $e -> makeSingleQuoted($attribs{state});
        return '';
    }
    elsif ($tag eq 'state') {
        if($attribs{id} !~ m{^[a-z][0-9a-z_]+}) {
            warn "\@id ($attribs{id}) for state element does not match m{^[a-z][0-9a-z_]+}";
            return '';
        }
        $e -> set_state('state-id', $attribs{id}) if defined $attribs{id};
        #warn "Entering state: $attribs{id}\n";
        defined $attribs{id} or warn("No \@id for state element");
        $e -> {SM_EDGES}{$attribs{id}} ||= { };
        $e -> {SM_EDGES}{$attribs{id}}{_INHERIT} = $e -> makeSingleQuoted($attribs{inherit}) if defined $attribs{inherit};
        $e -> {SM_VIEWS}{$attribs{id}} = $e -> makeSingleQuoted($attribs{view}) if defined $attribs{view};
        $e -> {SM_ERROR}{$attribs{id}}{prefix} = $e -> makeSingleQuoted($attribs{'error-prefix'}) if defined $attribs{'error-prefix'};
        $e -> {SM_ERROR}{$attribs{id}}{format} = $e -> makeSingleQuoted($attribs{'error-format'}) if defined $attribs{'error-format'};
        return '';
    }
    elsif ($tag eq 'transition') {
        if($attribs{state} !~ m{^[_a-z][0-9a-z_]+}) {
            warn "\@state ($attribs{state}) for transition element does not match m{^[_a-z][0-9a-z_]+}";
            return '';
        }
        $e -> set_state('transition-id', $attribs{state}) if defined $attribs{state};
        defined $attribs{state} or warn("No \@state for transition element");
        $e -> {SM_EDGES}{$e -> state('state-id')}{$attribs{state}} ||= { };
        $e -> {SM_EDGES}{$e -> state('state-id')}{$attribs{state}}{_INHERIT} 
            = $e -> makeSingleQuoted($attribs{inherit}) if defined $attribs{inherit};
        return '';
    }
    elsif ($tag eq 'variable') {
        # we're in a spec guarding a transition
        my $state = $e -> state('state-id');
        my $trans = $e -> state('transition-id');
        my $group = $e -> state('group-id');
        $state = '_' unless defined $state;
        $trans = '_' unless defined $trans;

        my $id = $e -> makeSingleQuoted($attribs{'id'});
        if(defined $group) {
            $id = $e -> makeSingleQuoted(eval "$group . '.' . $id")
        }
        else {
            $group = '_' unless defined $group;
        }
        $e -> set_state('variable-id', $id);

        my $var_info = { 
            id => $id,
        };

        if(defined $attribs{'dependence'}) {
            $var_info->{'dependence'} = $e -> makeSingleQuoted($attribs{'dependence'});
        }
        elsif(defined $e -> {SM_VARS}{$state}{$trans}{$group}{'_'}{dependence}) {
            $var_info->{'dependence'} = $e -> {SM_VARS}{$state}{$trans}{$group}{'_'}{dependence};
        }

        $e -> {SM_VARS} -> {$state}{$trans}{$group}{$id} = $var_info;
        return '';
    }
    elsif ($tag eq 'constraint') {
        $e -> reset_state('params');
        return '';
    }
    elsif ($tag eq 'filter') {
        my $id = $attribs{id};
        my $state = $e -> state('state-id');
        my $trans = $e -> state('transition-id');
        my $group = $e -> state('group-id');
        my $var   = $e -> state('variable-id');
        $state = '_' unless defined $state;
        $trans = '_' unless defined $trans;
        $group = '_' unless defined $group;
        $var   = '_' unless defined $var;

        my $code = '';
        if($id =~ m{:}) {
            my $ns;
            ($ns, $id) = split(/:/, $id, 2);
            # now we need to translate $ns to a namespaceuri
            my $tns = $e -> {Current_Element}{Namespaces}{$ns};
            warn "Unknown namespace ($ns)" unless defined $tns;
            $id =~ tr/-/_/;
            $id =~ s{[^a-zA-Z_0-9]+}{}g;
            $id = "filter_$id";
            my $pkg = $e -> ns_handler($tns);
            $code .= "\\\&${pkg}::${id}";
        }
        else { # default ns for filters is Data::FormValidator's own packaged filters
            $code = $e -> makeSingleQuoted($id);
        }
        if($code) {
            #warn "Pushing [$code] onto filters stack for <$state><$trans><$group><$var>\n";
            push @{$e -> {SM_VARS}{$state}{$trans}{$group}{$var}{filters}||=[]}, $code;
        }
        return '';
    }
    elsif ($tag eq 'group') {
        return '' if $e -> state('in-script');
        my $state = $e -> state('state-id');
        my $trans = $e -> state('transition-id');
        $state = '_' unless defined $state;
        $trans = '_' unless defined $trans;
        my $id;
        my %info;
        if($id = $e -> state('group-id')) {
            $info{dependence} = $e -> {SM_VARS}{$state}{$trans}{$id}{'_'}{dependence};
            $id = (eval $id) . "." . $attribs{'id'};
            $id = $e -> makeSingleQuoted($id);
        }
        else {
            $id = $e -> makeSingleQuoted($attribs{'id'});
        }

        $e -> set_state('group-id', $id);
        for my $a (qw(some dependence)) {
            $info{$a} = $e -> makeSingleQuoted($attribs{$a})
                if defined $attribs{$a} && $attribs{$a} ne '';
        }
        #warn "\$e -> {SM_VARS}{$state}{$trans}{$id}{'_'}: ", Data::Dumper -> Dump([\%info]);
        $e -> {SM_VARS}{$state}{$trans}{$id}{'_'} = \%info;
        return '';
    }
    elsif ($tag eq 'script') {
        my $sub_name;
        if($sub_name = $e -> state('state-id')) {
            if($e -> state('transition-id')) {
                $sub_name .= "_to_" . $e -> state('transition-id');
            }
            else {
                if($attribs{when} eq 'post' || $attribs{when} eq 'pre') {
                    $sub_name = $attribs{when} . "_" . $sub_name;
                }
                elsif($attribs{when}) {
                    warn "Unrecognized value for \@when for script element ('$attribs{when}' should be 'pre' or 'post')";
                }
            }
        } else {
            if($attribs{when} eq 'pre') {
                $sub_name = 'initialize';
            }
            elsif($attribs{when} eq 'post') {
                $sub_name = 'cleanup';
            }
            elsif($attribs{when}) {
                warn "Unrecognized value for \@when for script element ('$attribs{when}' should be 'pre' or 'post')";
            }
        }

        $e -> enter_state('in-script');
        $e -> push_state;
        $e -> reset_state('in-expression');
        $e -> set_state('script-name', $sub_name);

        my $ret = "sub $sub_name { \n" . <<'1HERE1'; # . "warn \"Entering $sub_name\n\";";
    my($sm) = shift;
    my %vars;
    my $R = Gestinanna::Request -> instance;
    my %data = (
        local => ($sm -> data -> {'out'} ||= {}),
        context => $sm -> data,
        solar => { },
        global => { },
    );
    local($_) = local($topic) = $data{local};
1HERE1
        # need to go through each namespace and get the start of script stuff...
        $ret .= $e -> get_script_start;
        #warn "Start script: ", $e -> get_script_start, "\n";
    #$ret .= <<1HERE1;
    #warn "Entering " . __PACKAGE__ . "::$sub_name\n";
#1HERE1

        # check to see if script can access the session data or not

        $ret .= <<EOF if exists $attribs{super} && defined $attribs{super} && $attribs{super} eq 'begin';
    {
    my \$state = \$sm -> SUPER::$sub_name;
    return \$state if defined \$state;
    }
EOF
        return $ret;
    }
    elsif($tag eq 'goto') {
        if($attribs{'state-machine'}) {
            my $sm = $e -> static_expr($attribs{'state-machine'});
            my $code = "Gestinanna::XSM::Op -> goto(filename => ($sm)[0]";
            if($attribs{state}) {
                my $state = $e -> static_expr($attribs{state});
                $code .= ", state => ($state)[0]";
            }
            if($attribs{'next-state'}) {
                my $state = $e -> static_expr($attribs{'next-state'});
                $code .= ", 'next-state' => ($state)[0]";
            }
            elsif($e -> state('state-id')) {
                $code .= ", 'next-state' => " . $e -> makeSingleQuoted($e -> state('state-id'));
            }
            return $code . ", args => " . $e -> enter_param;
        }
        if($attribs{state}) {
            my $state = $e -> static_expr($attribs{state});
            return "return ( ($state)[0] )" . $e -> semi;
        }   
    }
    elsif ($tag eq 'assert') {
        my $state = $attribs{state};
        $e -> push_state;
        #$e -> set_state('assert-state', $attribs{state});
        if($e -> state('in-expression')) {
            return "(" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ") ?\n";
        }
        else {
            return "unless(" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ") {\n";
        }
        return "return \"\Q$state\E\" unless(" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ");\n";
    }
    else {
        warn("Unrecognised tag: $tag");
    }

    return '';
}

sub end_element {
    my ($e, $node) = @_;

    my($tag, %attribs);
    
    $tag = $node->{Name};

    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }


    if ($tag eq 'statemachine') {
        # need to get everything together for the tail of the package
        my $ret = '';

        my %seen;

        # handle inheritances
        if(grep {defined} @{$e -> {SM_ISA}||[]}) {
            $ret .= "our \@ISA = (" . join(", ", map { $e -> makeSingleQuoted($_) } grep { !$seen{$_}++ } grep { defined } @{$e -> {SM_ISA}||[]}) . ");";
        }
        else {
            $ret .= "our \@ISA = ('Gestinanna::XSM::Base');";
        }

        %seen = ( );

        if(@{$e -> {SM_FILES}||[]}) {
            $ret .= "our \@FILES = (" . join(", ", map { $e -> makeSingleQuoted($_) } grep { !$seen{$_}++ } @{$e -> {SM_FILES}||[]}) . ");";
        }

        if(keys %{$e -> {SM_HASA}||{}}) {
            $ret .= "our \%HASA = ("
                 . join( ", ", 
                   map { $e -> makeSingleQuoted($_) => $e -> makeSingleQuoted($e -> {SM_HASA} -> {$_}) }
                   keys %{$e -> {SM_HASA}}
                 )
                 . "); ";
        }

        if(keys %{$e -> {SM_VIEWS}||{}}) {
            $ret .= "our \%VIEWS = ("
                 . join( ", ",
                   map { $e -> makeSingleQuoted($_) => $e -> {SM_VIEWS} -> {$_} }
                   keys %{$e -> {SM_VIEWS}} 
                 )
                 . "); ";
        }

        if(keys %{$e -> {SM_ALIASES}||{}}) {
            $ret .= "our \%ALIASES = ("
                 . join( ", ",
                   map { $_ => $e -> {SM_ALIASES} -> {$_} }
                   keys %{$e -> {SM_ALIASES}}
                 )
                 . "); ";
        }


        # handle various data tables? or build them piecemeal in the code?
        # at least do aliases here
        my $edges_code = 'our %EDGES = ( ';

        $edges_code .= "_INHERIT => " .  $e -> {SM_EDGES}{_INHERIT} . ", "
            if $e -> {SM_EDGES}{_INHERIT};

        foreach my $state (keys %{$e -> {SM_EDGES} || {}}) {
            #warn "Looking at state $state\n";
            next if $state eq '_INHERIT';
            $edges_code .= $e -> makeSingleQuoted($state) . ' => {';
            $edges_code .= "_INHERIT => " . $e -> {SM_EDGES}{$state}{_INHERIT} . ","
                if $e -> {SM_EDGES}{$state}{_INHERIT};
            foreach my $trans (keys %{$e -> {SM_EDGES}{$state} || {}}) {
                #warn "  Looking at transition $trans\n";
                next if $trans eq '_INHERIT';
                $edges_code .= $e -> makeSingleQuoted($trans) . ' => {';
                $edges_code .= "_INHERIT => " . $e -> {SM_EDGES}{$state}{$trans}{_INHERIT} . ","
                    if $e -> {SM_EDGES}{$state}{$trans}{_INHERIT};
                my $info = {
                    optional => [ ],
                    required => [ ],
                };

                my %vars;
                my %some;
                my %some_deps;

                foreach my $vars (
                    $e -> {SM_VARS}{'_'}{'_'},
                    $e -> {SM_VARS}{$state}{'_'},
                    $e -> {SM_VARS}{$state}{$trans},
                ) {
                    next unless defined $vars;
                    foreach my $g (keys %{$vars}) {
                        #warn "Looking at group $g\n";
                        #warn "Group: " . Data::Dumper -> Dump([$vars -> {$g}]);
                        foreach my $v (keys %{$vars -> {$g}||{}}) {
                            next if $v eq '_';
                            my $id = $v;
                            #warn "  Looking at var $id\n";
                            if(exists $vars{$id}) {
                                foreach my $k (keys %{$vars -> {$g}{$v}||{}}) {
                                    if($k eq 'dependence') {
                                        $vars{$id}{$k} = $vars -> {$g}{$v}{$k};
                                    }
                                    elsif($k =~ m{^filters|constraints$}) {
                                        push @{$vars{$id}{$k}||=[]}, @{$vars -> {$g}{$v}{$k}||[]};
                                        push @{$vars{$id}{$k}||=[]}, @{$vars -> {$g}{'_'}{$k}||[]};
                                    }
                                }
                                $vars{$id}{'dependence'} = $vars -> {$g}{'_'}{'dependence'} unless defined $vars{$id}{'dependence'};
                            }
                            else {
                                $vars{$id} = { %{$vars -> {$g}{$v}||{}} };
                                $vars{$id} -> {id} = $id;
                                $vars{$id}{'dependence'} = $vars -> {$g}{'_'}{'dependence'} unless defined $vars{$id}{'dependence'};
                            }
                        }
                        my $s;
                        if(($s = $vars->{$g}{'_'}{'some'}) && defined $s && $s ne 'q||') {
                            #warn "Got $s for $g\n";
                            $some{$g} = "[ $s, " . join(', ', grep { $_ ne '_' } keys %{$vars->{$g}}) . "]";
                            @some_deps{keys %{$vars->{$g}}} = undef;
                        }
                        #warn "some for $g: $some{$g}\n";
                        #warn "some_deps: ", join(", ", keys %some_deps), "\n";
                        # need to do group-based constraints here
                    }
                }

                use Data::Dumper;
                #warn "Vars: " , Data::Dumper -> Dump([\%vars]);
                my @global_filters;
                foreach my $vars (
                    $e -> {SM_VARS}{'_'}{'_'}{'_'}{'_'},
                    $e -> {SM_VARS}{$state}{'_'}{'_'}{'_'},
                    $e -> {SM_VARS}{$state}{$trans}{'_'}{'_'},
                ) {
                    foreach my $v (keys %vars) {
                        push @{$vars{$v}{constraints}||=[]}, @{$vars -> {'constraints'}||[]};
                    }
                    push @global_filters, @{$vars -> {'filters'}||[]};
                }

                $edges_code .= "optional => [" . join(", ", grep { !exists $some_deps{$_} && defined $vars{$_} -> {dependence} && $vars{$_} -> {dependence} eq 'q|OPTIONAL|' } keys %vars ) . "], ";
                $edges_code .= "required => [" . join(", ", grep { !exists $some_deps{$_} && !defined $vars{$_} -> {dependence} || $vars{$_} -> {dependence} eq 'q||' } keys %vars ) . "], ";

                $edges_code .= 'constraints => { ';
                foreach my $v (keys %vars) {
                    next unless @{$vars{$v}{constraints}||[]};
                    next if $v =~ m{\*$}; # wildcard ending
                    $edges_code .= " $v => [ " . join(", ", grep { defined && $_ ne 'q||' } @{$vars{$v}{constraints}}) . "], ";
                }
                $edges_code .= '}, field_filters => { ';
                foreach my $v (keys %vars) {
                    next unless @{$vars{$v}{filters}||[]};
                    next if $v =~ m{\*$}; # wildcard ending
                    $edges_code .= " $v => [ " . join(", ", @{$vars{$v}{filters}}) . "], ";
                }
                $edges_code .= '}, filters => [ ' . join(", ", @global_filters) . ' ], ';

                # still need dependency_groups, dependencies defaults overrides
                # 
                my @dependencies = keys %{ +{ map { $vars{$_}->{dependence} => undef } grep { defined($vars{$_}->{dependence}) && $vars{$_}->{dependence} ne 'q|OPTIONAL|' } keys %vars } };
                if(@dependencies) {
                    $edges_code .= 'dependencies => {';
                    foreach my $d (@dependencies) {
                        next if $d eq 'q||';
                        $edges_code .= "$d => [ "
                                    . join(", ", grep { $vars{$_} -> {dependence} eq $d } keys %vars)
                                    . '], ';
                    }
                    $edges_code .= '}, ';
                }
                #warn Data::Dumper -> Dump([\%some], [qw(*some)]);
                if(keys %some) {
                    $edges_code .= 'require_some => {'
                                .  join(", ", map { join(' => ', $_, $some{$_}) } keys %some)
                                . '}, ';
                }
                $edges_code .= '}, ';
            }
            $edges_code .= '}, ';
        }
        $edges_code .= ');';

        $ret .= $edges_code;

        #warn "Edges code: $edges_code\n";

        return $ret;
    }
    elsif ($tag eq 'state') {
        $e -> reset_state('state-id');
    }
    elsif ($tag eq 'transition') {
        $e -> reset_state('transition-id');
    }
    elsif ($tag eq 'variable') {
        $e -> reset_state('variable-id');
        return '';
    }
    elsif ($tag eq 'constraint') {
        my $state = $e -> state('state-id');
        my $trans = $e -> state('transition-id');
        my $group = $e -> state('group-id');
        my $var   = $e -> state('variable-id');
        $state = '_' unless defined $state;
        $trans = '_' unless defined $trans;
        $group = '_' unless defined $group;      
        $var   = '_' unless defined $var;

        my $params = $e -> state('params');

        #warn "my params: $params\n";
 
        my @code;
        my $id = $attribs{id};
        my $constraint;
        if($attribs{equal}) {
           push @code, "sub { \$_[0] eq " . $e -> makeSingleQuoted($attribs{equal}) . " }";
        }
        if($attribs{'max-length'}) {
           push @code, "sub { length(\$_[0]) <= " . $e -> makeSingleQuoted($attribs{'max-length'}) . " }";
        }
        if($attribs{'min-length'}) {
           push @code, "sub { length(\$_[0]) >= " . $e -> makeSingleQuoted($attribs{'min-length'}) . " }";
        }
        if($attribs{'length'}) {
           push @code, "sub { length(\$_[0]) == " . $e -> makeSingleQuoted($attribs{'length'}) . " }";
        }
        unless(defined $id) {
        }
        elsif($id =~ m{:}) {
            my $ns;
            ($ns, $id) = split(/:/, $id, 2);
            # now we need to translate $ns to a namespaceuri
            my $tns = $e -> {Current_Element}{Namespaces}{$ns};
            warn "Unknown namespace ($ns)" unless defined $tns;
            $id =~ tr/-/_/;  
            $id =~ s{[^a-zA-Z_0-9]+}{}g;
            $id = "valid_$id";
            my $pkg = $e -> ns_handler($tns);
            $constraint = "\\\&${pkg}::${id}";
        }
        else { # default ns for constraints is Data::FormValidator's own packaged constraints
            if($id eq 'equal') {
                $constraint = 'sub { $_[0] eq $_[1] }';
            }
            else {
                $constraint = $e -> makeSingleQuoted($id);
            }
        }
        if($constraint && $params) {
            if($var ne '_' && $params !~ m{(^|,\s*)\Q$var\E(,|$)}) {
                 $params = $var . ", $params";
            }
            push @code, <<EOF;
{
    constraint => $constraint,
    params => [ $params ],
}
EOF
        }
        else {
            push @code, $constraint,
        }

        if($attribs{'max-length'}) {
            push @code, "sub { length(\$_[0]) <= " . $e -> makeSingleQuoted($attribs{'max-length'}) . " }";
        }
        if($attribs{'min-length'}) {
            push @code, "sub { length(\$_[0]) >= " . $e -> makeSingleQuoted($attribs{'min-length'}) . " }";
        }

        if(@code) {
            #warn "Pushing [" . join(";;;", @code) . "] onto constraints stack for <$state><$trans><$group><$var>\n";
            push @{$e -> {SM_VARS}{$state}{$trans}{$group}{$var}{constraints}||=[]}, @code;
        }
        return '';
    }
    elsif ($tag eq 'filter') {
        return '';
    }
    elsif ($tag eq 'group') {
        return '' if $e -> state('in-script');
        my $id = $e -> state('group-id');
        $id = eval $id;
        my $own_id = $attribs{'id'};
        $id =~ s{\.?\b\Q$own_id\E$}{};
        if($id ne '') {
            $e -> set_state('group-id', $e -> makeSingleQuoted($id));
        }
        else {
            $e -> reset_state('group-id');
        }
    }
    elsif ($tag eq 'script') {
        my $script = $e -> state('script');
        my $script_super = $attribs{'super'};
        my $sub_name = $e -> state('script-name');
        $e -> pop_state;
        $e -> set_state('script', $script);
        $e -> leave_state('in-script');
        my $ret = "";
        $ret .= $e -> get_script_end;
        return "$ret\n}" . $e -> semi if $e -> state('in-script');
        return <<EOF if defined $script_super && $script_super eq 'end';
    $ret
    {
    my \$state = \$sm -> SUPER::$sub_name;
    return \$state if defined \$state;
    }
    return;
}
EOF
        return " return;\n}\n";
    }
    elsif ($tag eq 'assert') {   
        my $state = $e -> static_expr($attribs{state});
        my $script = $e -> state('script');
        $e -> pop_state;
        $e -> set_state('script', $script);
        return "return $state; }" . $e -> semi;
    }
    elsif($tag eq 'goto') {
        if($attribs{'state-machine'}) {
            return $e -> leave_param . $e -> semi;
            my $script = $e -> state('script');
            my $a = '%goto' . $e -> state('in-goto');
            $e -> pop_state; 
            $e -> set_state(script => $script);
            return "; \\$a; } )" . $e -> semi;
        }
        return '';
    }

    return '';
}

sub path_to_dotted { my $p = $_[0]; $p =~ tr[/][.]; return $p; }

1;

__END__
