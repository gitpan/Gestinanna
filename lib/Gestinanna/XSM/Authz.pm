####
# Functions implementing authx:* processing
####

package Gestinanna::XSM::Authz;

use strict;

use base qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/authz';

sub start_document {
    return "#initialize authz namespace\n";
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

# <authz:assert select="object" or type="..." path="..." -- state="...">...</authz:assert>
        
    if ($tag eq 'assert') {
        # set up environment for <and/> and <or/> and <has/> and <has-not/>
        # worry about attributes, etc., when we close the tag
        $e -> push_state;
        $e -> reset_state($_) for qw(
            in-authz-and
            in-authz-or
            in-expression
            authz-and-level
            authz-or-level
        );
        $e -> enter_state("authz-or-level");
        return "do { my \@authz_or1; "; #}
    }
    elsif( $tag eq 'and' || $tag eq 'or' ) {
        my $in = $e -> state("in-authz-$tag");
        $e -> enter_state("in-authz-$tag");
        return '' if $in; # do nothing - flatten nested identical tags
        $e -> push_state;
        $e -> reset_state("in-authz-and") if $tag eq 'or';
        $e -> reset_state("in-authz-or") if $tag eq 'and';
        $e -> enter_state("authz-${tag}-level");
        $in = $e -> state("authz-${tag}-level");
        my $a = '@authz_' . $tag . $in;
        return "do { my $a; "; # }
    }
    elsif( $tag eq 'has' || $tag eq 'has-not' ) {
        my $and = $e -> state('in-authz-and') ? 'and' : 'or';
        my $in = $e -> state("authz-${and}-level");
        my $var = "\@authz_${and}${in}";
        my $attr = $attribs{attribute};
        $attr = "!$attr" if $tag eq 'has-not';
        if($e -> state('in-expression')) {
            return "((push $var, " . $e -> makeSingleQuoted($attr) . "), undef)[1]" . $e -> semi;
        }
        return "push $var, " . $e -> makeSingleQuoted($attr) . $e -> semi;
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

    if($tag eq 'assert') {
        my $code = $e -> state('script');
        $e -> pop_state;
        $e -> set_state(script => $code);

        my $select;
        $code = '';
        $select = Gestinanna::XSM::compile_expr($e, $attribs{select}) if $attribs{select};
        my($state, $type, $path, $attribute) = map { $e -> static_expr($_) } @attribs{qw(state type path attribute)};
        if($select) {
            # base it on select and path
            # expect the objects to be POF objects
            $attribute = '*' unless defined $attribute && $attribute ne '';
            $code = <<EOF
grep { UNIVERSAL::isa(\$_, 'Gestinanna::POF::Base') && \$_ -> has_access($attribute, \\\@authz_or1) }
     $select
EOF
        } elsif(defined $path && defined $type) {
            $path .= "($path . '\@' . $attribute)" if defined $attribute && $attribute ne '';
            #$path = $e -> makeSingleQuoted($path);
            #$type = $e -> makeSingleQuoted($type);
            my $factory = '$R -> factory';
            $code = <<EOF;
$factory -> {authz} -> has_attribute(
    [ eval { $factory -> {actor} -> object_type }, eval { $factory -> {actor} -> object_id } ],
    [ $type, $path ],
    \\\@authz_or1
)
EOF
        }
        if($code) {
            $code = "unless($code) { return ( ($attribs{state})[0] ); }";
        }
        else {
            $code = "undef;";
        }
        return "$code }" . $e -> semi;
    }
    elsif($tag eq 'and' || $tag eq 'or') {
        my $in = $e -> state("in-authz-$tag");
        if($in > 1) {
            $e -> leave_state("in-authz-$tag");
            return '';
        }
        my($own_var, $next_var);
        my $other_tag = ($tag eq 'and') ? 'or' : 'and';

        $own_var = '@authz_' . $tag . $e -> state("authz-${tag}-level");
        $next_var = '@authz_' . $other_tag . $e -> state("authz-${other_tag}-level");

        my $code = $e -> state('script');
        $e -> pop_state;
        $e -> set_state(script => $code);
        if($e -> state('in-expression')) {
            return "((push $next_var, \\$own_var), undef)[1]" . $e -> semi;
        }
        return "push $next_var, \\$own_var;" . $e -> semi;
    }

    return '';
}

sub xsm_has_access ($$$$) {
    my($sm, $type, $path, $attr) = @_;

    my $R = Gestinanna::Request -> instance;
    #return 0 unless $R -> factory -> {actor};

    my $actor;
    if($R -> factory -> {actor}) {
        $actor = $sm -> {_cache}{authz}{actor} ||= [
            $R -> factory -> {actor} -> object_type,
            $R -> factory -> {actor} -> object_id,
        ];
    }
    else {
        $actor = [ 'user', 'guest' ];
    }

    #warn "has_access($$actor[0], $$actor[1], $type, $path, $attr)\n";

    return 0 unless defined $type && $type ne '';
    return 0 unless defined $path && $path ne '';

    return 0 unless defined $R -> factory -> {authz};

    my $ret = $R -> factory -> {authz} -> has_attribute(
        $actor, [ $type, $path ], $attr
    );

    #warn "  returning $ret\n";
    return $ret;
}    

sub xsm_actor ($) {
    my($sm) = @_;

    my $R = Gestinanna::Request -> instance;

    my $actor;

    if($R -> factory -> {actor}) {
        $actor = $sm -> {_cache}{authz}{actor} ||= [
            $R -> factory -> {actor} -> object_type,
            $R -> factory -> {actor} -> object_id,
        ];
    }
    else {
        $actor = [ 'user', 'guest' ];
    }

    return $actor;
}

1;
