####
# Functions implementing pof:* processing
####

package Gestinanna::XSM::POF;

use base qw(Gestinanna::XSM);

#our @ISA = qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/pof';

sub start_document {
    return "#initialize pof namespace\n";
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

my %test_types = qw( lt < le <= gt > ge >= eq = ne != contains CONTAINS );
 
sub start_element {
    my ($e, $node) = @_;
    
    my ($tag, %attribs);
     
    $tag = $node->{Name};
     
    foreach my $attrib (@{$node->{Attributes}}) {
        $attribs{$attrib->{Name}} = $attrib->{Value};
    }
        
    if ($tag eq 'find') {
        my $limit;
        if($attribs{start}) {
            $limit = "limit => [";
            if($attribs{limit}) {
                $limit .= "0 + (" . Gestinanna::XSM::compile_expr($e, $attribs{limit}) . ")[0], ";
            }
            else {
                $limit .= " undef, ";
            }
            $limit .= " 0 + (" . Gestinanna::XSM::compile_expr($e, $attribs{start}) . ")[0] ]";
        }
        elsif($attribs{limit}) {
            $limit = "limit => ( 0 + (" . Gestinanna::XSM::compile_expr($e, $attribs{start}) . ")[0] )";
        }
            
        return "\$R -> factory -> find(\"\Q$attribs{type}\E\", $limit, where => (";
    }
    elsif($tag eq 'and') {
        return "[ AND => (";
    }
    elsif($tag eq 'or') {
        return "[ OR => (";
    }
    elsif($tag eq 'not-and') {
        return "[ NOT => AND => (";
    }
    elsif($tag eq 'not-or') {
        return "[ NOT => OR => (";
    }
    elsif($tag eq 'test') {
        my $test = $test_types{$attribs{type}};
        return '' unless $test;
        return "[ \"\Q$attribs{attribute}\E\", '$test', (" .  Gestinanna::XSM::compile_expr($e, $attribs{select}) . ")[0] ]" . $e -> semi;
    }
    elsif($tag eq 'not-test') {
        my $test = $test_types{$attribs{type}};
        return '' unless $test;
        return "[ NOT => \"\Q$attribs{attribute}\E\", '$test', (" .  Gestinanna::XSM::compile_expr($e, $attribs{select}) . ")[0] ]" . $e -> semi;
    }
    elsif($tag eq 'exists') {
        return "[ \"\Q$attribs{attribute}\E\", 'EXISTS' ]" . $e -> semi;
    }
    elsif($tag eq 'not-exists') {
        return "[ NOT => \"\Q$attribs{attribute}\E\", 'EXISTS' ]" . $e -> semi;
    }
    elsif($tag eq 'new') {
        # allow arguments to build the object_id - with proper escaping
        my $type = $e -> static_expr($attribs{type});
        return __PACKAGE__ . "::new_object(($type)[0]," .  $e -> enter_param;
    }
    else {
        warn("Unrecognised tag: $tag");
    }

#           [ AND => (
#                [ 'name', '=', 'some name' ],
#                [ OR => (
#                     [ 'age',  '<', '40' ],
#                     [ 'postalcode', '=', '12345' ]
#                  )
#                ]
#              )
#            ]


    return '';
}

sub end_element {
    my ($e, $node) = @_;
     
    my $tag = $node->{Name};

    if($tag eq 'find') {
        return ") || [ ] )" . $e -> semi;
    }
    elsif($tag eq 'and' || $tag eq 'or' || $tag eq 'not-and' || $tag eq 'not-or') {
        return ') ], ';
    }
    elsif($tag eq 'new') {
        return $e -> leave_param . $e -> semi;
    }

    return '';
}

sub new_object {
    my($type, $params) = @_;

    my $R = Gestinanna::Request -> instance;
    #warn "type: " . Data::Dumper -> Dump([$type]) . "\n";

    my $ob = $R -> factory -> new($type, %$params);
    #warn "ob: $ob\n";
    return $ob;
}

sub xsm_new($$$) {
    my($sm, $type, $object_id) = @_;

    #warn "type: $type;  object_id: $object_id\n";
    $type = ref $type ? $type->[0] : $type;
    $object_id = ref $object_id ? $object_id -> [0] : $object_id;

    #warn "keys in statemachine object: " . join(", ", keys %{$_[0]}), "\n";
    #warn "type: $type  object_id: $object_id\n";
    return new_object($type, { object_id => $object_id });
}

sub xsm_types($) {
     my $R = Gestinanna::Request -> instance;
     my @types = grep { $_ !~ m{^_} } 
                ($R -> factory -> get_loaded_types(), 
                 $R -> factory -> get_registered_types()
                )
               ;

#    warn "pof types: " . join(", ", @types) . "\n";
    return @types;
}

sub xsm_valid_type($$) {
    my $sm = shift;
    my $R = Gestinanna::Request -> instance;

    return 0 if $_[0] =~ m{^_};

    eval {
        $R -> factory -> get_factory_class($_[0]);
    };

#    warn "valid_type($_[0]): " . ($@ ? 0 : 1) . "\n";

    my $e = $@;
    undef $@; # to make sure we don't catch something we shouldn't later
    return 0 if $e;
    return 1;
}

1;
