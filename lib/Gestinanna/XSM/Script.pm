####
# Functions implementing script:* processing
####

package Gestinanna::XSM::Script;

our @ISA = qw(Gestinanna::XSM);
use strict;

our $NS = 'http://ns.gestinanna.org/script';

#__PACKAGE__ -> register;

sub start_document {
    return "#initialize script namespace\nuse Log::Log4perl;\n";
}

sub end_document {
    return '';
}

sub start_script {
    return "my \$log = Log::Log4perl::get_logger();\n";
}

sub end_script {
    return "";
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

my %expression_state = map { $_ => 1 } qw(
    association
    choose
    considering
    delayed
    dump
    for-each
    if
    list
    log
    otherwise
    try
    value
    value-of
    variable
    when
);

sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);

    $tag = $node->{Name};
    
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }

    if($e -> state('in-expression') && !$expression_state{$tag}) {
        warn "<$tag/> can not appear in an expression context\n";
        return "";
    }

    if ($tag eq 'variable') {
        $e -> {SM_Variable_select} = defined $attribs{select};
        $e -> enter_state('in-expression');
        $e -> enter_state('in-list');
        my $select = '';
        $select = Gestinanna::XSM::compile_expr($e, $attribs{select}) . "," if defined $attribs{select};
        my $t = "t" . $e -> state('in-expression');
        return '$vars{' . $e -> static_expr($attribs{name}) . "} = do { my \@$t = $select";
    }
    elsif ($tag eq 'with-param') {
        if($e -> state('in-param')) {
            my $name = $e -> static_expr($attribs{'name'});
            $e -> enter_state('in-expression');
            my $t = "\@t" . $e -> state('in-expression');
            my $a = "\$params" . $e -> state('in-param');
            my $select = '';
            $select = Gestinanna::XSM::compile_expr($e, $attribs{select}) . ',' if $attribs{'select'};
            return $a . "{($name)[0]} = do { my $t = ($select";
            #return $a . '{' . __PACKAGE__ . "::path_to_dotted(($name)[0])} = do { my $t = ($select";
        }
        else {
            return '';
        }
    }
    elsif ($tag eq 'param') {
        my $id = $attribs{id};
        $id = $e -> makeSingleQuoted($id);
        my $group = $e -> state('group-id');
        if($group && $group ne 'q||') {
            $id = $e -> makeSingleQuoted(eval "${group} . '.' . ${id}");
        }
        $e -> set_state(params =>
            $e -> state('params') . $id . ', '
        );
        #warn "params now: " . $e -> state('params') . "\n";
        return '';
    }
    elsif ($tag eq 'script') {
        $e -> push_state;
        $e -> reset_state('in-expression');
        return "sub { \n";
    }
    elsif ($tag eq 'delayed') {
        $e -> push_state;
        $e -> reset_state('is-expression');
        return 'Apache -> request -> post_connection(sub {';
    }
    elsif ($tag eq 'log') {
        $e -> enter_state('in-expression');
        $e -> enter_state('in-list');
        $e -> enter_state('in-text');
        my $level = $attribs{level};
        $level = 'debug' unless $level =~ m{^(debug|info|warn|error|fatal)$};
        return "\$log -> $level(";
    }
    elsif ($tag eq 'considering') {
        if($e -> state('in-expression')) {
            my $v = 'results' . $e -> state('in-expression');
            return "do { my \@$v; for(" . Gestinanna::XSM::compile_expr($e, $attribs{select}) . ") { local(\$topic) = \$_; push \@$v, (";
        }
        return '{ local($topic) = ' . Gestinanna::XSM::compile_expr($e, $attribs{select}) . ';';
    }
    elsif ($tag eq 'for-each') {
        $e -> push_state;
        $e -> reset_state('script');
        $e -> reset_state('in-expression');
        $e -> set_state('sort-script', Gestinanna::XSM::compile_expr($e, $attribs{select}));
        $e -> set_state('for-each-as', $attribs{as});
        return '';
    }
    elsif ($tag eq 'sort') {
        # we want to use a transform to do the sorting
        my $select = Gestinanna::XSM::compile_expr($e, $attribs{select});
        $e -> set_state('sort-script', 'map { $_ -> [1] } sort { Gestinanna::XSM::Expression::xsm_cmp( $a->[0], $b->[0] ) } ' 
                                       . " map { [ [ grep { defined } map { $select } \$_ ], \$_ ] } "
                                       . $e -> state('sort-script'));
        return '';
    }
    elsif ($tag eq 'while') {
        my $limit = $attribs{'limit'};
        my $test = $attribs{'test'};
        return '' unless defined $test;
        $limit = 1000 unless defined $limit;
        return '';
    }
    elsif ($tag eq 'choose') {
        $e -> push_state;
        $e -> reset_state('script');
        $e -> reset_state('choose-otherwise');
        $e -> enter_state('in-choose');
        if($e -> state('in-expression')) {
            return "(";
        }
        return "if(0) { ";
    }
    elsif ($tag eq 'when') {
        if($e -> state('in-choose')) {
            if($e -> state('in-expression')) {
                return "(" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ") ? (\n";
            }
            return " }  elsif(" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ") {\n";
        }
        else {
            if($e -> state('in-expression')) {
                return "(" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ") ? (\n";
            }
            return "if(" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ") {\n";
        }
    }
    elsif ($tag eq 'otherwise') {
        unless($e -> state('in-choose')) {
            warn("The otherwise element may only appear within a choose element");
            return '';
        }
        $e -> push_state;
        $e -> reset_state('script');
        return '';
    }
    elsif ($tag eq 'if') {
        if($e -> state('in-expression')) {
            return "( (" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ") ? (";
        }
        return "if(" . Gestinanna::XSM::compile_expr($e, $attribs{test}) . ") {\n";
    }
    elsif ($tag eq 'try') {
        $e -> push_state;
        $e -> enter_state('in-try');
        $e -> reset_state('in-expression');
        return "eval {\n";
    }
    elsif ($tag eq 'value-of') {
        if($node -> {Parent} -> {Name} eq 'list' && !$e -> state('in-expression')) {
            my $l = '@l' . $e -> state('in-list');
            return "push $l, (" . Gestinanna::XSM::compile_expr($e, $attribs{select}) . "); ";
        }
        return Gestinanna::XSM::compile_expr($e, $attribs{select});
    }
    elsif ($tag eq 'value') {
        # used to add an object to a tree
        my $name = $attribs{name};

        my $select = "";
        $select = Gestinanna::XSM::compile_expr($e, $attribs{select}) . ","
            if defined $attribs{select};
        my $scope = '$data{"local"}';
        if($name =~ m{::}) {
            ($scope, $name) = split(/::/, $name, 2);
            $scope = "\$data{\"\Q$scope\E\"}";
        }
        elsif($name =~ m{^\$}) {
            ($scope, $name) = split(/\//, $name, 2);
            $scope =~ s{^\$}{};
            $scope = "\$vars{\"\Q$scope\E\"}";
        }
        elsif($name !~ m{^/} && $e -> state('in-association')) {
            $e -> enter_state('in-expression');
            my $t = "\@t" . $e -> state('in-expression');
            my $a = "\$a" . $e -> state('in-association');
            return $a . "{\"\Q$name\E\"} = do { my $t = ($select";
        }
        my @bits = grep { defined && $_ ne '' } split(/\//, $name);
        #warn "Compiled: $attribs{select} => $select\n";
        $e -> enter_state('in-expression');
        foreach (@bits) {
            #warn "bit: $_\n";
            s{^\$(.*)}{\$vars{"\Q$1\E"}}
                    ||
            s{(.*)}{"\Q$1\E"};
            #warn "     $_\n";
        }
        return "Gestinanna::XSM::Expression::set_element($scope, [ " . join(", ", @bits) . " ], $select ";
    }
    elsif($tag eq 'set-namespace') {
        my $select;
        $select = Gestinanna::XSM::compile_expr($e, $attribs{select}) . ","
            if $attribs{select};
        $e -> enter_state('in-expression');
        return "if(!defined \$data{\"\Q$attribs{name}\E\"}) { my \@t; \$data{\"\Q$attribs{name}\E\"} = ( (\@t = ($select";
    }
    elsif($tag eq 'association') {
        $e -> push_state;
        $e -> enter_state('in-association');
        $e -> reset_state('in-expression');
        my $a = '%a' . $e -> state('in-association');
        return "do { my $a;";
    }
    elsif($tag eq 'list') {
        $e -> push_state;
        $e -> enter_state('in-list');
        $e -> reset_state('in-expression');
        my $l = '@l' . $e -> state('in-list');
        return "do { my $l;";
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

    if ($tag eq 'variable') {
        my $t = "t" . $e -> state('in-expression');
        $e -> leave_state('in-expression');
        $e -> leave_state('in-list');
        return "; scalar(\@$t) > 1 ? \\\@$t : \$$t\[0]; }" . $e -> semi;
    }
    elsif ($tag eq 'script') {
        my $script = $e -> state('script');
        $e -> pop_state;
        $e -> set_state('script', $script);
        return "}" . $e -> semi;
    }
    elsif ($tag eq 'delayed') {
        my $script = $e -> state('script');
        $e -> pop_state;
        $e -> set_state('script', $script);
        return '} )' . $e -> semi;
    }
    elsif ($tag eq 'log') {
        $e -> leave_state('in-expression');
        $e -> leave_state('in-text');
        $e -> leave_state('in-list');
        return ")" . $e -> semi;
    }
    elsif ($tag eq 'debug') {
        #$e -> enter_state('ignore') unless $e -> {SM_Debug};
    }
    elsif ($tag eq 'considering') {
        return '' unless $e -> state('in-script');
        if($e -> state('in-expression')) {
            my $v = 'results' . $e -> state('in-expression');
            return "); } \@$v; }" . $e -> semi;
        }
        return "}" . $e -> semi;
    }
    elsif ($tag eq 'for-each') {
        my $body = '';
        my $as = $e -> static_expr($attribs{'as'});
        if(defined $as && $as ne 'q||') {
            $body .= "\$vars{$as} = \$_; ";
        } 
        $body .= "local(\$topic) = \$_; ";
        $body .= '$sm -> {script_data} -> {position} -> [0] ++;';

        $body .= $e -> state('script');
        my $array = $e -> state('sort-script');
        $e -> pop_state;
        if($node -> {Parent} -> {Name} eq 'list' && !$e -> state('in-expression')) {
            my $l = '@l' . $e -> state('in-list');
            return <<EOF;
push $l, ( do { 
    unshift \@{\$sm -> {script_data} -> {position} ||= []}, -1; 
    my \@_b = ($array); 
    unshift \@{\$sm -> {script_data} -> {last} ||= []}, scalar(\@_b) - 1; 
    my \@_a = map { $body } (\@_b); 
    shift \@{\$sm -> {script_data} -> {position}}; 
    shift \@{\$sm -> {script_data} -> {last}}; 
    \@_a; 
} );
EOF
        }
        if($e -> state('in-expression')) {
            return <<EOF;
do { 
    unshift \@{\$sm -> {script_data} -> {position} ||= []}, -1; 
    my \@_b = ($array); 
    unshift \@{\$sm -> {script_data} -> {last} ||= []}, scalar(\@_b) - 1; 
    my \@_a = map { $body } (\@_b); 
    shift \@{\$sm -> {script_data} -> {position}}; 
    shift \@{\$sm -> {script_data} -> {last}}; 
    \@_a; 
}
EOF
        }
        return <<EOF;
unshift \@{\$sm -> {script_data} -> {position} ||= []}, -1; 
my \@_b = ($array);
unshift \@{\$sm -> {script_data} -> {last} ||= []}, scalar(\@_b) - 1;
foreach (\@_b) { 
    $body 
}
shift \@{\$sm -> {script_data} -> {position}};
shift \@{\$sm -> {script_data} -> {last}};
EOF
    }
    elsif ($tag eq 'choose') {
        return '' unless $e -> state('in-script');
        my $script = $e -> state('script');
        $script = "" unless defined $script;
        my $o = $e -> state('choose-otherwise');
        $e -> pop_state;
        if($e -> state('in-expression')) {
            if($o) {
                return "$script $o )";
            }
            return "$script () )";
        }
        if(defined $o && $o ne '') {
            $script .= " } else { $o }";
        }
        else {
            $script .= " }";
        }
        $script =~ s{^if\(0\)\s*{\s*}\s*els}{};
        $script =~ s{\s*else\s*{\s*}$}{};
        return $script;
    }
    elsif ($tag eq 'when') {
        if($e -> state('in-expression')) {
            return ' ) : ';
        }
        return "";
    }
    elsif ($tag eq 'otherwise') {
        return '' unless $e -> state('in-choose') || $e -> state('in-try');
        my $script = $e -> state('script');
        $e -> pop_state;
        $e -> set_state('choose-otherwise', $script);
        return '';
    }
    elsif ($tag eq 'if') {
        if($e -> state('in-expression')) {
            return ') : () ) ' . $e -> semi;
        }
        return "}\n";
    }
    elsif($tag eq 'try') {
        return '' unless $e -> state('in-script');
        my $o = $e -> state('choose-otherwise');
        my $script = $e -> state('script');
        $e -> pop_state;
        if($e -> state('in-expression')) {
            return "}, ((\$@) ? do { $o } : ())";
        }
        return "};\nif(\$@) {\n  $o \n }\n";
    }
    elsif($tag eq 'with-param') {
        if($e -> state('in-param')) {
            my $t = 't' . $e -> state('in-expression');
            $e -> leave_state('in-expression');
            return "); scalar(\@$t) > 1 ? \\\@$t : \$$t\[0]; };";
        }
        return '';
    }
    elsif($tag eq 'value') {
        if($attribs{name} !~ m{^[\/\$]} && $attribs{name} !~ m{::} && $e -> state('in-association')) {
            my $t = 't' . $e -> state('in-expression');
            $e -> leave_state('in-expression');
            return "); scalar(\@$t) > 1 ? \\\@$t : \$$t\[0]; };";
        }
        $e -> leave_state('in-expression');
        return ")" . $e -> semi;
    }
    elsif($tag eq 'set-namespace') {
        $e -> leave_state('in-expression');
        return ") > 0) ? \\\@t : \$t[0]) }" . $e -> semi;
    }
    elsif($tag eq 'value-of') {
        return $e -> semi;
    }
    elsif($tag eq 'association') {
        my $script = $e -> state('script');
        my $a = '%a' . $e -> state('in-association');
        $e -> pop_state;
        $e -> set_state(script => $script);
        return "; \\$a; }" . $e -> semi;
    }
    elsif($tag eq 'list') {
        my $script = $e -> state('script');
        my $l = '@l' . $e -> state('in-list');
        $e -> leave_state('in-list');
        $e -> pop_state;
        $e -> set_state(script => $script);
        return "; \\$l; }" . $e -> semi;
    }
    return '';
}

sub path_to_dotted { my $p = $_[0]; $p =~ tr[/][.]; return $p; }

###
### some helpful functions
###

sub xsm_clone ($@) { shift; @{Storable::dclone([ @_ ])}; }
sub xsm_concat ($@) { shift; join('', @_) }
sub xsm_contains ($$$) { $_[1] =~ m{\Q$_[2]\E} ? 1 : 0 }
sub xsm_count ($@) { scalar(@_)-1 }
sub xsm_dump ($@) { shift; require Data::Dumper; Data::Dumper -> Dump([@_]); } # do we really want this?
sub xsm_defined ($$) { defined($_[1]) }
sub xsm_ends_with ($$$) { $_[1] =~ m{\Q$_[2]\E$} ? 1 : 0 }
sub xsm_false ($) { 0 }
sub xsm_is_a ($$$) { UNIVERSAL::isa(@_[1,2]) }
sub xsm_list ($\@) { return [ map { UNIVERSAL::isa($_, 'ARRAY') ? @$_ : $_ } @{$_[1]||{}} ]; }
sub xsm_not ($$) { !$_[1] }
sub xsm_gmt_now ($) { 
    # want yyyymmddhhmmss
    my @t = (gmtime)[0..5];
    $t[5] += 1900;
    $t[4]++;
    
    return sprintf("%04d%02d%02d%02d%02d%02d", @t[5,4,3,2,1,0]);
}
sub xsm_last($) { $_[0] -> {script_data} -> {last} -> [0] if UNIVERSAL::isa($_[0]->{script_data}{last}, 'ARRAY'); }
sub xsm_number ($$) { 0+$_[1] }
sub xsm_null ($) { undef }
sub xsm_position ($) { $_[0] -> {script_data} -> {position} -> [0] if UNIVERSAL::isa($_[0]->{script_data}{position}, 'ARRAY'); }
sub xsm_splice ($\@$$;@) {
    my($sm, $array, $start, $length) = splice @_, 0, 4;
    my @array = @{$array || []};
    #warn "splice($array, $start, $length)\n";
    if(@_) {
        splice @array, $start, $length, @_;
    }
    else {
        splice @array, $start, $length;
    }

    return \@array;
}
sub xsm_starts_with ($$$) { $_[1] =~ m{^\Q$_[2]\E} ? 1 : 0 }
sub xsm_string ($$) { ""+$_[1] }
sub xsm_string_cmp ($$$) { $_[1] cmp $_[2] }
sub xsm_string_length ($$) { length($_[1]) }
sub xsm_substring ($$$;$) { 
    #warn "substring(" . join(",", @_) . ")\n";
    return '' unless defined $_[1];
    return '' if $_[3] < 0 || $_[2] < 0;
    return substr($_[1], $_[2]) if @_ == 3;
    return substr($_[1], $_[2], $_[3]) if @_ == 4;
    return '';
}
sub xsm_substring_after ($$$) {
    return $1 if $_[1] =~ m{\Q$_[2]\E(.*)};
    return '';
}
sub xsm_substring_before ($$$) {
    return $1 if $_[1] =~ m{^(.*?)\Q$_[2]\E};
    return '';
}
sub xsm_sum ($@) {
    shift;
    my $sum;
    $sum += $_ for @_;
    return $sum;
}
sub xsm_translate ($$$$) {
    my $s = $_[1];
    eval "$s =~ tr[\Q$_[2]\E][\Q$_[3]\E];";
    return $s;
}
sub xsm_true ($) { 1 }

sub xsm_unique($@) {
    shift;
    my @ret = eval { 
        values %{ +{ map { Storable::freeze(\$_) => $_ } @_ } };
    };
    return @_ if $@;
    return @ret;
}

1;

__END__
