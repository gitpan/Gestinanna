####
# Functions implementing workflow:* processing
####

#
#  need to load workflow definitions during server startup
#    -- tie into XSM initialization/configuration
#  
#  or we can use the workflow:$path as the name of the workflow and load on demand
#
#  still need to manage conditions, etc.
#
#
#  $ob = workflow:create('type');
#  $ob = workflow:fetch('type', $id);
#  @ids = workflow:find('type', 'user', 'state') # any that are blank/undef or '*' are not used as criteria
#  @available_actions = $ob/current-actions
#  @fields = $ob/method::get-action-fields( $action )
#  @required_fields = $ob/method::get-action-fields( $action )[is-required = 1]
#  ## do we want to be able to take the get-action-fields data and use it in the statemachine?
#  $context = $ob/context
#  $context/method::param( $field_name, $data )
#  $ob/method::execute-action( $action )
#  $state = $ob/state
#
# ## set $ob/context/method::param('user', $user_id) in the workflow:create() and workflow:fetch() calls
# ##  (assuming this isn't saved unless there is a change in state)
# ## need to be able to assign ownership -- might be able to through acl system, but not the best
#
# $id = $ob/id
# $type = $ob/type
# $description = $ob/description
#
# to be supported by Workflow::Persister::Gestinanna :
# need to be able to search based on user / type / state
#   database can support search on type and state
#   need to add user field that indicates owner / initial creator
#
# need to allow script elements in condition and action definitions --
#    may need to refactor compiler a slight bit to allow this
# - make script elements a different namespace -- should solve most of it
#  then just compile with <conditions/> or <actions/> root element instead of <statemachine/>
#  this needs a little more thought
#

package Gestinanna::XSM::Workflow;

use base qw(Gestinanna::XSM);
use strict;

use Gestinanna::XSM::Expression;

#our @ISA = qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/workflow';

sub start_document {
    return "#initialize workflow namespace\n";
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

sub manage_text { 1 }
            
sub characters {
    my ($e, $text) = @_;
 
    return $text -> {Data};
    $e -> append_state('script', $text);

    return '';
}

sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);
     
    $tag = $node->{Name};
     
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }
    warn "start $tag: ", join(", ", map { "$_ => $attribs{$_}" } keys %attribs), "\n";
        
    if ($tag eq 'workflow') {
      # root of workflow definition
    }
    elsif ($tag eq 'inherit') {
        # need to load inherited definition and overwrite with new stuff
    }
    elsif( $tag eq 'state') {
        $e -> push_state;
        $e -> set_state('description', '');
    }
    elsif( $tag eq 'description') {
        $e -> push_state;
        $e -> set_state('text', '');
    }
    elsif( $tag eq 'action') {
        if($attribs{'id'}) {
            $e -> push_state;
            $e -> reset_state('in-expression');
            $e -> set_state('script', '');
            $e -> enter_state('workflow-action');
            $e -> {WF_CONDITIONS} = [ ];
        }
        else {
            $e -> {WF_CONDITIONS} = [ ];
        }
    }
    elsif( $tag eq 'condition') {
        if($attribs{'xref'}) {
            push @{$e -> {WF_CONDITIONS} ||= []}, $attribs{'xref'};
        }
        elsif($attribs{'id'}) {
            $e -> push_state;
            $e -> reset_state('in-expression');
            $e -> set_state('script', '');
        }
    }
    elsif( $tag eq 'validator') {
        if($attribs{'xref'}) {
            push @{$e -> {WF_VALIDATORS} ||= []}, $attribs{'xref'};
        }
        elsif($attribs{'id'}) {
            $e -> push_state;
            $e -> reset_state('in-expression');
            $e -> set_state('script', '');
        }
    }
    elsif( $tag eq 'param') {
        $e -> push_state;
        $e -> set_state('init', '');
    }
    elsif( $tag eq 'field') {
        $e -> push_state;
        $e -> reset_state('in-expression');
        $e -> set_state('script', '');
    }
    elsif( $tag eq 'add-context' ) {
        $e -> enter_state('in-expression');
        $e -> enter_state('in-list');
        my $wf = Gestinanna::XSM::compile_expr($e, $attribs{workflow});
        my $select = $attribs{select};
        $select = '' unless defined $select;
        $select = Gestinanna::XSM::compile_expr($e, $select) . ", " if $select ne '';
        return "Gestinanna::XSM::Workflow::xsm_add_context(\$sm, $wf, [ $select";
    }
    elsif( $tag eq 'choose-action' ) {
        $e -> push_state;
        $e -> reset_state('script');
        $e -> reset_state('workflow-action-otherwise');
        $e -> enter_state('in-workflow-action');
        my $wfv = '$wf' . $e -> state('in-workflow-action');
        my $wf = Gestinanna::XSM::compile_expr($e, $attribs{workflow});
        if($e -> state('in-expression')) {
            return "( (my $wfv = $wf, (";
        }
        return "my $wfv = $wf;\nif(0) { ";
    }
    elsif( $tag eq 'when' ) {
        my $wfv = '$wf' . $e -> state('in-workflow-action');
        if($e -> state('in-expression')) {
            return "(Gestinanna::XSM::Workflow::execute_action($wfv, " . Gestinanna::XSM::static_expr($e, $attribs{action}) . ") ? (\n";
        }
        return " }  elsif(Gestinanna::XSM::Workflow::execute_action($wfv, " . Gestinanna::XSM::static_expr($e, $attribs{action}) . ")) {\n";

    }
    elsif( $tag eq 'otherwise' ) {
        $e -> push_state;
        $e -> reset_state('script');
        return '';
    }
    elsif( $tag eq 'add-history' ) {
        my $wf = $attribs{workflow};
        if(defined $wf) {
            $wf = Gestinanna::XSM::compile_expr($e, $wf);
        }
        elsif($e -> state('in-workflow-action')) {
            $wf = '$wf' . $e -> state('in-workflow-action');
        }
        elsif($e -> state('workflow-action')) {
            $wf = '$wf';
        }
        else {
            $wf = "undef";
        }
        $e -> push_state;
        $e -> enter_state('in-association');
        $e -> reset_state('in-expression');
        my $a = '%a' . $e -> state('in-association');
        return "Gestinanna::XSM::Workflow::add_history($wf, do { my $a;";
    }
    else {
        warn("Unrecognised tag: $tag");
    }

    return '';
}

sub end_element {
    my ($e, $node) = @_;
     
    my $tag = $node->{Name};
    my (%attribs);

    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }
    warn "end $tag: ", join(", ", map { "$_ => $attribs{$_}" } keys %attribs), "\n";
        
    if ($tag eq 'workflow') {
        my $script_start = $e -> get_script_start;
        my $script_end = $e -> get_script_end;

        my $data = {
            workflow => {
                state => $e -> {WF_STATE} || [],
                description => $e -> state('description') || '',
                persister => $attribs{'persister'} || '',
            },
            condition => $e -> {WF_DEF_CONDITIONS} || {},
            validator => $e -> {WF_DEF_VALIDATORS} || {},
            action => $e -> {WF_DEF_ACTIONS} || {},
        };

        my(%action_map, %condition_map, %validator_map);

        foreach my $parent (reverse @{$e -> {WF_PARENTS} || []}) {
            my %a = $parent -> action_map;
            @action_map{keys %a} = values %a;
            %a = $parent -> condition_map;
            @condition_map{keys %a} = values %a;
            %a = $parent -> validator_map;
            @validator_map{keys %a} = values %a;
        }

        warn Data::Dumper -> Dump([$data]);

# __PACKAGE__::Actions::$Action = package for $Action
# __PACKAGE__::Conditions::$Condition
# ...
# loaded at server startup - not on-demand
# by taglib
#
#  <content-provider type="xsm">
#    <taglibs>
#      <taglib "workflow">
#        <workflow name="name used in factory" type="workflow" name="file"/>
#      </taglib>
#    </taglibs>
#  </content-provider>

        foreach my $a (@{$data -> {action} || []}) {
            $action_map{$a -> {name}} = qq{__PACKAGE__ . "::Actions::$$a{name}"};
        }

        foreach my $c (@{$data -> {condition} || []}) {
            $condition_map{$c -> {name}} = qq{__PACKAGE__."::Conditions::$$c{name}"};
        }

        #foreach my $v (@{$data -> {validator} || []}) {
            #$validator_map{$v -> {name}} = \__PACKAGE__."::Validators::$$v{name}";
        #}

        my $code = '';
        my $pkg_code = '';

        $code .= <<1HERE1;
use base qw(Gestinanna::Workflow);

use vars qw(\%WORKFLOW \%ACTION_MAP \%CONDITION_MAP \%VALIDATOR_MAP \%ACTIONS \%CONDITIONS \%VALIDATORS);
1HERE1

        $code .= "\%ACTION_MAP = (\n    "
              . join(",\n    ", map { qq{$_ => $action_map{$_}} } keys %action_map)
              . "\n);\n\n";
        $code .= "\%CONDITION_MAP = (\n    "
              . join(",\n    ", map { qq{$_ => $condition_map{$_}} } keys %condition_map)
              . "\n);\n\n";
        $code .= "\%VALIDATOR_MAP = (\n    "
              . join(",\n    ", map { qq{$_ => $validator_map{$_}} } keys %validator_map)
              . "\n);\n\n";

        my $description = Gestinanna::XSM::makeSingleQuoted($data -> {workflow} -> {description});
        my $persister = Gestinanna::XSM::makeSingleQuoted($data -> {workflow} -> {persister});

        $code .= <<1HERE1;
\%WORKFLOW = (
    description => $description,
    persister => $persister,
    state => [
1HERE1

        foreach my $state (@{$data -> {workflow} -> {state} || []}) {
            $description = Gestinanna::XSM::makeSingleQuoted($state -> {description});
            my $name = Gestinanna::XSM::makeSingleQuoted($state -> {name});
            $code .= <<1HERE1;
        {
            name => $name,
            description => $description,
            action => [
1HERE1

            foreach my $action(@{$state -> {action} || []}) {
                $name = $action_map{$action -> {name}};
                #$name = Gestinanna::XSM::makeSingleQuoted($action -> {name});
                my $resulting_state = Gestinanna::XSM::makeSingleQuoted($action -> {resulting_state});
                $code .= <<1HERE1;
                {
                    name => $name,
                    resulting_state => $resulting_state,
1HERE1
                $code .= "                    condition => ["
                      . join(", ", map { qq{{ name => \__PACKAGE__."::Conditions::${_}"}} } @{$action -> {condition} || []})
                      . "],\n";

                $code .= <<1HERE1;
                },
1HERE1
            }
            $code .= <<1HERE1;
            ],
        },
1HERE1

        }
        $code .= "    ],\n);\n";

        $code .= "\n%ACTIONS = (\n";
        foreach my $action (@{$data -> {action} || []}) {
            my $package = $action_map{$action -> {name}};
            my $name = qq{$package};
            if(0 && $package =~ m{^__PACKAGE__}) {
                $package =~ s{^__PACKAGE__\s*\.\s*"}{};
                $package =~ s{"$}{};
                $package = "__PACKAGE__$package";
            }

            $pkg_code .= <<1HERE1;
{
    my \$package = $package;
    eval "package \$package;" . <<'EOCODE';

    use base qw(Workflow::Action);

    sub execute {
        my( \$self, \$wf ) = \@_;
        my \$sm = { };
        my \%data = (
            local => Gestinanna::XSM::Workflow::xsm_context_params(undef, \$wf),
            session => { },
        );
        $script_start
        $$action{code}
    }
EOCODE
}
1HERE1

            $code .= <<1HERE1;
    $name => {
        class => $name,
        field => [
1HERE1

            foreach my $field (@{$action->{field}||[]}) {
                $name = Gestinanna::XSM::makeSingleQuoted($field->{name});
                my $required = Gestinanna::XSM::makeSingleQuoted($field -> {is_required});
                my $type = Gestinanna::XSM::makeSingleQuoted($field -> {type});
                
                $code .= <<1HERE1;
                    {
                        name => $name,
                        is_required => $required,
                        param => [
1HERE1
                foreach my $param (@{$field -> {param}||[]}) {
                    $name = Gestinanna::XSM::makeSingleQuoted($param->[0]);
                    my $value = Gestinanna::XSM::makeSingleQuoted($param->[1]);
                    $code .= <<1HERE1;
                            [ $name, $value ],
1HERE1
                }
                $code .= <<1HERE1;
                        ],
                    },
1HERE1
            }

            $code .= <<1HERE1
        ],
    },
1HERE1
        }
        $code .= ");\n";

        $code .= "\n%CONDITIONS = (\n";
        foreach my $cond (@{$data -> {condition} || []}) {
            my $package = qq{\__PACKAGE__ . "::Conditions::$$cond{name}"};
            #my $name = Gestinanna::XSM::makeSingleQuoted($cond -> {name});
            my $name = $package;
            my $accessors = join("\n        ", map { Gestinanna::XSM::makeSingleQuoted($_ -> [0]) } @{$cond->{params}||[]});
            $pkg_code .= <<1HERE1;
{ 
    my \$package = $package;
    eval "package \$package; " . <<'EOCODE';

    use base qw(Workflow::Condition);

    \__PACKAGE__ -> mk_accessors(
        $accessors
    );

    sub _init {
        my ( \$self, \$params ) = \@_;
        my \%data = (
            local => \$params,
            self => \$self,
            session => { },
        );
        $script_start
        $$cond{init}
    }

    sub evaluate {
        my( \$self, \$wf ) = \@_;
        my \%data = (
            local => Gestinanna::XSM::Workflow::xsm_context_params(undef, \$wf),
            session => { },
        );
        $script_start
        $$cond{code}
    }
EOCODE
}

1HERE1

            #$package =~ s{^__PACKAGE__(.*)$}{__PACKAGE__ . "$1"};
            $code .= <<1HERE1;
    $name => {
        class => $package,
        param => [
1HERE1

            foreach my $p (@{$cond -> {params}||[]}) {
                $name = Gestinanna::XSM::makeSingleQuoted($p -> [0]);
                my $value = Gestinanna::XSM::makeSingleQuoted($p -> [1]);
                $code .= <<1HERE1
            $name => $value,
1HERE1
            }

            $code .= <<1HERE1;
        ],
    },
1HERE1
        }

        $code .= ");\n";
        
        return $code . $pkg_code;
    }
    elsif ($tag eq 'inherit') {
    }
    elsif( $tag eq 'state') {
        push @{$e->{WF_STATE}||=[]}, {
            name => $attribs{id},
            action => $e->{WF_ACTIONS} || [],
            description => $e -> state('description'),
        };
        delete $e -> {WF_ACTIONS};
        $e -> pop_state;
    }
    elsif( $tag eq 'description') {
        my $d = $e -> state('text');
        $d =~ s{\s+}{ }gm;
        $e -> pop_state;
        $e -> set_state('description', $d);
    }
    elsif( $tag eq 'action') {
        if($attribs{'id'}) {
            # defining the action with the enclosed script
            push @{$e -> {WF_DEF_ACTIONS}||=[]}, {
                name => $attribs{'id'},
                code => $e -> state('script'),
                field => $e -> {WF_FIELDS} || [],
                validator => $e -> {WF_VALIDATORS} || [],
            };
            $e -> pop_state;
            delete $e -> {WF_FIELDS};
            delete $e -> {WF_VALIDATORS};
        }
        elsif($attribs{'xref'}) {
            # referencing a definition from elsewhere
            if($attribs{'xref'} =~ m{^[A-Za-z_][A-Za-z_0-9]+$}) {
                push @{$e -> {WF_ACTIONS}||= []}, {
                    name => $attribs{'xref'},
                    resulting_state => $attribs{'resulting-state'},
                    condition => $e -> {WF_CONDITIONS} || [],
                };
           }
           else {
               warn "Illegal <action/> xref: [$attribs{'xref'}]\n";
           }
           delete $e -> {WF_CONDITIONS};
        }
    }
    elsif( $tag eq 'condition') {
        if($attribs{'id'}) {
            push @{$e -> {WF_DEF_CONDITIONS} ||= []}, {
                name => $attribs{'id'},
                code => $e -> state('script'),
                init => $e -> state('init'),
                params => $e -> {WF_PARAMS} || [],
            };
            $e -> pop_state;
        }
    }
    elsif( $tag eq 'init' ) {
        my $script = $e -> state('script');
        $e -> pop_state;
        $e -> append_state('init', $script);
    }
    elsif( $tag eq 'validator') {
        if($attribs{'id'}) {
            push @{$e -> {WF_DEF_VALIDATORS} ||= []}, {
                name => $attribs{'id'},
                code => $e -> state('script'),
                params => $e -> {WF_PARAMS} || [],
            };
            $e -> pop_state;
        }
    }
    elsif( $tag eq 'param') {
        push @{$e -> {WF_PARAMS} ||= [ ]}, [ $attribs{id}, $attribs{value} ];
        my $init = $e -> state('init');
        if($init ne '') {
            $init = '<considering select="' . $attribs{id} . qq{">$init</considering>};
        }
        $e -> pop_state;
        $e -> append_state('init', $init);
    }
    elsif( $tag eq 'field') {
        push @{$e -> {WF_FIELDS}}, {
            name => $attribs{id},
            is_required => $attribs{required} || 'no',
            type => $attribs{type},
            source => $e -> state('script'),
            source_class => $attribs{'source-class'},
            param => $e -> {WF_PARAMS} || [],
        };
        $e -> pop_state;
        $e -> {WF_PARAMS} = [ ];
    }
    elsif( $tag eq 'add-context' ) {
        my $script = $e -> state('script');
        $e -> pop_state;
        $e -> set_state(script => $script);
        return '])' . $e -> semi;
    }
    elsif( $tag eq 'choose-action' ) {
        my $script = $e -> state('script');
        $script = "" unless defined $script;
        my $o = $e -> state('choose-action-otherwise');
        $e -> pop_state;
        if($e -> state('in-expression')) {
            if($o) {
                return "$script $o ) )[1])";
            }
            return "$script () ) ) )";
        }
        if(defined $o && $o ne '') {
            $script .= " } else { $o }";
        }
        else {
            $script .= " }";
        }
        $script =~ s{;\s*if\(0\)\s*{\s*}\s*els}{; };
        $script =~ s{\s*else\s*{\s*}$}{};  
        return $script;
    }
    elsif( $tag eq 'when' ) {
        if($e -> state('in-expression')) {
            return ' ) : ';
        }
        return "";
    }
    elsif( $tag eq 'otherwise' ) {
        my $script = $e -> state('script');
        $e -> pop_state;
        $e -> set_state('choose-action-otherwise', $script);
        return '';
    }
    elsif( $tag eq 'add-history' ) {
        my $script = $e -> state('script');
        my $a = '%a' . $e -> state('in-association');
        $e -> pop_state;
        $e -> set_state(script => $script);
        return "; \\$a; })" . $e -> semi;
    }

    return '';
}

sub execute_action {
    my($wf, $action) = @_;

    return unless $wf;

    eval { $wf -> execute_action($action) };
    if($@) {
        warn "$@\n";
        return 0;
    }
    return 1;
}

sub add_history {
    my($wf, $attrs) = @_;

    return unless $wf;

    my %params;
    if(defined $attrs->{action}) {
        $params{action} = $attrs->{action};
    }
    else {
        $params{action} = 'No action specified.';
    }

    if(defined $attrs->{description}) {
        $params{description} = $attrs->{description};
    }
    else {
        $params{description} = 'No description.';
    }

    $params{state} = $wf -> state;

    $wf -> add_history( \%params );
}

sub xsm_create($$) {
    my $type = $_[1];
    my $factory = Gestinanna::Request -> instance -> config -> workflow_factory;
    return $factory -> create_workflow($type);
}

sub xsm_fetch($$$) {
    my $type = $_[1];
    my $id = $_[2];
    my $factory = Gestinanna::Request -> instance -> config -> workflow_factory;
    return $factory -> fetch_workflow($type, $id);
}

sub xsm_create_context($$) {
    my $list = $_[1];

    use Data::Dumper;
    warn "xsm_create_context(...): ", Data::Dumper -> Dump([$list]);
    $list = [ $list ] unless UNIVERSAL::isa($list, 'ARRAY');
    my $c = Workflow::Context -> new;

    _add_hash($c, '', $_) foreach @$list;

    warn "Resulting context: ", Data::Dumper -> Dump([$c]);

    return $c;
}

sub xsm_add_context($$$) {
    my $wf = $_[1];
    my $list = $_[2];

    my $c = xsm_create_context($_[0], $list);
    warn "Context returned\n";
    $wf -> context -> param($c -> param());
    warn "Context merged\n";
}

sub _add_hash {
    my($c, $prefix, $hash) = @_;

    warn "_add_hash($c, $prefix, $hash)\n";

    if(UNIVERSAL::isa($hash, 'ARRAY')) {
        for(my $i = 0; $i < @$hash; $i++) {
            if(ref $hash->[$i]) {
                _add_hash($c, "${prefix}${i}.", $hash->[$i]);
            }
            else {
                $c -> param("${prefix}${i}", $hash->[$i]);
            }
        }
    }
    elsif(UNIVERSAL::isa($hash, 'HASH')) {
        foreach my $k (keys %$hash) {
            if(ref $hash->{$k}) {
                _add_hash($c, "${prefix}${k}.", $hash -> {$k});
            }
            else {
                $c -> param("${prefix}${k}", $hash->{$k});
            }
        }
    }
}

sub xsm_context_params($$) {
    my $c = $_[1];

    $c = $c -> [0] if UNIVERSAL::isa($c, 'ARRAY');

    $c = $c -> context if UNIVERSAL::isa($c, "Workflow");

    warn "xsm_context_params(..., $c)\n";

    return { } unless $c;

    my $hash = $c -> param;

    my $ret = { };
    foreach my $k (keys %$hash) {
        Gestinanna::XSM::Expression::set_element($ret, [split(/\./, $k)], $hash->{$k});
    }

    use Data::Dumper;
    warn "context: ", Data::Dumper -> Dump([$c]);
    warn "returning ", Data::Dumper -> Dump([$ret]);

    return $ret;
}
sub xsm_find($$$;$) {
    my($sm, $type, $state, $user) = @_;

# still need to do searches
    # $state may be a list of values

    my $factory = Gestinanna::Request -> instance -> config -> workflow_factory;

    my $pof_type = 'workflow';

    my $pof_factory = Gestinanna::Request -> instance -> factory;

    my @where;
    push @where, 'AND' if $state || $user;
    if($state) {
        if(ref $state) {
            push @where, [ state => 'IN' => @$state ];
        }
        elsif($state) {
            push @where, [ state => '=' => $state ];
        }
    }
    if(ref $user) {
        push @where, [ user_type => '=' => $user -> [0] ];
        push @where, [ user_id   => '=' => $user -> [1] ];
    }
    elsif($user) {
        push @where, [ user_type => '=' => 'actor'];
        push @where, [ user_id   => '=' => $user  ];
    }

    use Data::Dumper;
    warn "Where: ", Data::Dumper -> Dump([\@where]);

    my $iterator = $pof_factory -> find( $pof_type => (
        where => [ @where, [ type => '=' => $type ] ],
    ) );

    my @requests;

    my $id;

    while($id = $iterator -> next_id) {
        warn "Found $id\n";
        push @requests, $factory -> fetch_workflow($type, $id);
    }

    return @requests;
}

1;
