####
# Functions implementing content-provider:* processing
####

package Gestinanna::XSM::ContentProvider;

our @ISA = qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/content-provider';

__PACKAGE__ -> register;

sub start_document {
    return "#initialize content-provider namespace\n";
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

#my %test_types = qw( lt < le <= gt > ge >= eq = ne != );
 
sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);
     
    $tag = $node->{Name};
     
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }

    if( $tag eq 'process' ) {
        my $select = Gestinanna::XSM::compile_expr($e, $attribs{select});
        $select = "$select," if defined $select && $select ne '';

        $e -> enter_state('in-expression');
        return __PACKAGE__ . "::process(\$sm, " . join(", ", map { $e -> makeSingleQuoted($_) } @attribs{qw(type id)})
               . ", $select";
    }
    else {
        warn("Unrecognised tag: $tag");
    }

    return '';
}

sub end_element {
    my ($e, $node) = @_;
     
    my $tag = $node->{Name};

    if($tag eq 'process') {
        $e -> leave_state('in-expression');
        return ')' . $e -> semi;
    }

    return '';
}

sub process {
    my($sm, $type, $id) = splice @_, 0, 3;

    my @args;
    while(@_) {
        my $k = shift @_;
        if(UNIVERSAL::isa($k, 'HASH')) {
            push @args, %$k;
        }
        elsif(UNIVERSAL::isa($k, 'ARRAY')) {
            push @args, @$k;
        }
        else {
            push @args, $k, shift @_;
        }
    }

    my $args = { @args };

    my @path = ((map { ($_ -> filename) }
                     $sm, $sm -> get_super_path($sm -> state)),
                '/sys/default');

    my $R = Gestinanna::Request -> instance;

    foreach my $p (@path) {
        #warn "Trying $p/$id\n";
        my $cp = $R -> get_content_provider(
            args => $args,
            filename => "$p/$id",   
            type => $type,
            include_path => \@path,
        );
        if($cp) {
            my $msg = $cp -> content;
            warn "Content: [$$msg]\n";
            return $$msg;
        }
        #return $cp -> content if $cp;
    }

    return '';
}

1;
