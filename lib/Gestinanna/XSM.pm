package Gestinanna::XSM;

use Gestinanna::XSM::Base;
use Gestinanna::XSM::Expression::Parser;
use Storable;

use strict;

use utf8;

sub register {
    my $class = shift;
    no strict 'refs';
    $Gestinanna::XSM::tag_lib{${"${class}::NS"}} = $class;
}

sub makeSingleQuoted($) {
    my $value = shift;
    $value = shift if ref $value;
    return 'undef' unless defined $value;
    $value =~ s/([\\|])/\\$1/g;
    return 'q|'.$value.'|';
}

sub is_sm_namespace {
    my $ns = shift;

    return $ns eq "http://ns.gestinanna.org/statemachine";
}

sub semi { $_[0] -> state('in-expression') ? ($_[0] -> state('in-list') ? ',' : '') : ';'; }

sub push_state {
    my $e = shift;

    push @{$e -> {SM_State_Stack} ||= [ ]}, $e -> {SM_State};

    $e -> {SM_State} = { %{$e -> {SM_State} || {}} }; # copy
}

sub pop_state {
    my $e = shift;

    $e -> {SM_State} = pop @{$e -> {SM_State_Stack} ||= []} || { };
}

sub reset_state {
    my $e = shift;

    return delete $e -> {SM_State}->{$_[0]};
}

sub state {
    my $e = shift;

    return $e -> {SM_State}->{$_[0]};
}

sub leave_state {
    my $e = shift;

    $e -> {SM_State} -> {$_[0]} --;
}

sub enter_state {
    my $e = shift;

    $e -> {SM_State} -> {$_[0]} ++;
}

sub append_state {
    my $e = shift;

    $e -> {SM_State} -> {$_[0]} .= $_[1]; 
}

sub enter_param {
    my $e = shift;
    $e -> push_state;
    $e -> enter_state('in-param');
    $e -> reset_state('in-expression');
    my $a = '%params' . $e -> state('in-param');
    return "do { my $a; ";
}

sub leave_param {
    my $e = shift;
    my $script = $e -> state('script');
    my $a = '%params' . $e -> state('in-param');
    $e -> pop_state;
    $e -> set_state(script => $script);
    return "; \\$a; } )";
}

sub set_state {
    my $e = shift;

    $e -> {SM_State} -> {$_[0]} = $_[1];
}

sub compile_expr {
    my $e = shift;
    my $expr = shift;

    my $code = Gestinanna::XSM::Expression::Parser->parse($e, $expr);

    #warn "$expr -> $code\n";

    return $code;
}

# when you expect a static expression, use the following to allow interpolated expressions
sub static_expr {
    my $e = shift;
    my $expr = shift;

    return 'undef' unless defined $expr;
    if($expr =~ m{^{(.*)}$}) {
        return $e -> compile_expr($1);
    }
    else {
        return $e -> makeSingleQuoted($expr);
    }
}

sub compile {
    my $class = shift;
    my $xml = shift;
    my %params = @_;

    #main::diag("xml: $xml");
    my $handler = Gestinanna::XSM::SAXHandler -> new_handler(
        %params,
        SM_Debug => 1,
    );

    # we can handle xslt stuff in the SAXParser
    #   that's where we end up with a dom all the time
    #   regardless of what we get from our caller
    #   will need the $factory object and request
    #   objects of type `xslt', imho 

    my $parser = Gestinanna::XSM::SAXParser -> new(
        provider => $xml,
        Handler => $handler,
        factory => $params{factory},
    );

    my $to_eval;

    eval {
        $to_eval = $parser -> parse($xml);
    };

    if($@) {
        die "Parse failed: $@\n";
    }

    my $data;
#    eval {
#        $data = $class -> compile_data($xml);
#    };

    if($@) {
        die "Parse failed: $@\n";
    }

#           isa => \@isa,
#        hasa => \%hasa,
#        views => \%views,
#        aliases => \%aliases,
#        edges => \%edges,

    $to_eval = 'use vars qw(@ISA %HASA %VIEWS %ALIASES %EDGES $topic);' . "\n"
    #         . Data::Dumper->Dump([@{$data}{qw(isa hasa views aliases edges)}], [qw(*ISA *HASA *VIEWS *ALIASES *EDGES)])
    #         . "\n$$data{code}\n"
             . $to_eval;

    if($to_eval) {
        eval {
            require Perl::Tidy;

            my $errors;
            my $res;
            Perl::Tidy::perltidy(
                source => \$to_eval,
                destination => \$res,
                stderr => \$errors,
                argv => '-se -npro -f -nsyn -pt=2 -sbt=2 -csc -csce=2 -vt=1 -lp -cab=3 -iob');
            if ($errors) {
                warn "PerlTidy warnings: $errors\n";
            } else {
                #AxKit::Debug(5,"PerlTidy successful");
            }
            $to_eval = $res;
        };
    }

    return $to_eval;
}

use XML::XPath;
use Data::Dumper;

sub compile_data {
    my $self = shift;
    my $xml = shift;

    my $xp;

    eval {
        $xp = XML::XPath->new( xml => $xml );
    };

    return if $@;  # unable to parse XML

    $xp -> set_namespace('gst', $Gestinanna::XSM::Core::NS);

    my(%edges,
       %hasa,
       @isa,
       %views,
       %aliases,
       $code,
    );

    # handle %HASA and @ISA
    my($statemachine) = $xp -> findnodes('gst:statemachine');

    foreach my $node ($xp -> findnodes('gst:inherit', $statemachine)) {
        my $class = $xp -> findvalue('@class', $node);
        my $prefix = $xp -> findvalue('@prefix', $node);
        # need to load $class
        if($prefix && defined $hasa{$prefix}) {
#            warn "[", join(".", unpack("U", $self -> revision)), "]:", 
#            warn $self -> name, " already has a state machine with the prefix `$prefix'.\n";
            next;
        }
        unless( $class =~ m{::} ) {
#            my $class_obj = $self -> {_factory} -> new( statemachine => name => $class );
            if($prefix) {
#                $hasa{$prefix} = $class_obj -> compile;
                $hasa{$prefix} = "".$class;
            }
            else {
#                push @isa, $class_obj -> compile;
                push @isa, "".$class;
            }
        }
        else {
            eval "require $class";
            if($@) {
                warn "Unable to load $class\n";
            }
            else {
                push @isa, "".$class;
            }
        }
    }

    # handle %ALIASES
    foreach my $node ($xp -> findnodes('gst:alias', $statemachine)) {
        my $state = "".$xp -> findvalue('@state', $node);
        my $id = $xp -> findvalue('@id', $node);
        $aliases{$id} = $state if $id && $state;
    }

    # now handle %EDGES
    my $t = "".$xp -> findvalue('@inherit');
    $edges{_INHERIT} = $t if $t;

    # iterate through each <state/>
    foreach my $state ($xp -> findnodes('gst:state', $statemachine)) {
        my $state_id = $xp -> findvalue('@id', $state);
        next unless $state_id;

        my($error_format, $error_prefix);
        $t = "".$xp -> findvalue('@error_prefix', $state);
        $error_prefix = $t if $t;
        $t = "".$xp -> findvalue('@error_format', $state);
        $error_format = $t ne '' ? $t : "%s";

        $t = "".$xp -> findvalue('@view', $state);
        $views{$state_id} = $t if $t;

        $t = "".$xp -> findvalue('@inherit', $state);
        $edges{$state_id}{_INHERIT} = $t if $t;

        # iterate through each <transition/> within each <state/>
        foreach my $transition ($xp -> findnodes('gst:transition', $state)) {
            my $trans_id = $xp -> findvalue('@state', $transition);
            next unless $trans_id;

            $t = "".$xp -> findvalue('@inherit', $transition);
            $edges{$state_id}{$trans_id}{_INHERIT} = $t if $t;

            # find <variable/>s that are marked OPTIONAL
            $t = [ map { "".$xp -> findvalue('@id', $_) } (
                grep { !$xp -> findnodes(q{ancestor::script}, $_) }
                $xp -> findnodes(q{
                    gst:variable[@dependence="OPTIONAL"] 
                    | ../gst:variable[@dependence="OPTIONAL"] 
                }, $transition)
            ) ];

            push @$t, map { $xp -> findvalue('../@id', $_) . "." . $xp -> findvalue('@id', $_) } (
                $xp -> findnodes(q{
                    gst:group[@some]/gst:variable[@dependence!="REQUIRED"]
                    | ../gst:group[@some]/gst:variable[@dependence!="REQUIRED"]
                    | gst:group[@dependence="OPTIONAL"]/gst:variable
                    | ../gst:group[@dependence="OPTIONAL"]/gst:variable
                }, $transition)
            );

            $edges{$state_id}{$trans_id}{optional} = $t if @{$t};

            # find <variable/>s that are not OPTIONAL
            $t = [ map { "".$xp -> findvalue('@id', $_) } (
                grep { !$xp -> findnodes(q{ancestor::script}, $_) }
                $xp -> findnodes(q{
                    gst:variable[@dependence!="OPTIONAL"]
                    | ../gst:variable[@dependence!="OPTIONAL"]
                }, $transition)
            ) ];

            push @$t, map { $xp -> findvalue('../@id', $_) . "." . $xp -> findvalue('@id', $_) } (
                $xp -> findnodes(q{
                    gst:group[@some]/gst:variable[@dependence="REQUIRED"]
                    | ../gst:group[@some]/gst:variable[@dependence="REQUIRED"]
                    | gst:group[@dependence!="OPTIONAL" and not(@some)]/gst:variable
                    | ../gst:group[@dependence!="OPTIONAL" and not(@some)]/gst:variable
                }, $transition)
            );

            $edges{$state_id}{$trans_id}{required} = $t if @{$t};

            # now <constraint/>s and <filter/>s and <message/>s in <variable/>s
            foreach my $variable (
                grep { !$xp -> findnodes(q{ancestor::script}, $_) }
                $xp -> findnodes(q{
                    .//gst:variable | ../gst:variable | ../gst:group/gst:variable
                }, $transition)) 
            {
                my(@constraints, @filters, @defaults, $missing_message, %invalid_messages);
                my $var_id = $xp -> findvalue('@id', $variable);
                if($xp -> exists("parent::gst:group", $variable)) {
                    $var_id = $xp -> findvalue('parent::gst:group/@id', $variable) . "." . $var_id;
                }
                foreach my $constraint ($xp -> findnodes('gst:constraint', $variable)) {
                    $t = $xp -> findvalue('@id', $constraint);
                    if($t) {
                        push @constraints, "".$t;
                        my $tt = $xp -> findvalue('gst:message', $constraint);
                        $invalid_messages{$t} = $tt;
                        next;
                    }

                    my $e = "".$xp -> findvalue('@equal', $constraint);
                    if($e) {
                        #push @constraints, qq{sub { \$_[0] eq "\Q$e\E" }};
                        $code .= "push \@{\$EDGES{'$state_id'}{'$trans_id'}{constraints}{'$var_id'}||=[]}, sub { \$_[0] eq \"\Q$e\E\" };";
                        next;
                    }
                }

                @filters = map { "".$xp -> findvalue('@id', $_) } 
                               ($xp -> findnodes('gst:filter', $variable));

                @defaults = map { "".$xp -> findvalue('.', $_) } 
                                ($xp -> findnodes('gst:default', $variable));

                $t = "".$xp -> findvalue('gst:message', $variable);
                $missing_message = $t if $t;

                next unless @constraints || @filters || @defaults || keys(%invalid_messages) || $missing_message;

                #$t = $xp -> findvalue('@id', $variable);

                #if($xp -> exists("parent::gst:group", $variable)) {
                #    $t = $xp -> findvalue('parent::gst:group/@id', $variable) . "." . $t;
                #}

                push @{$edges{$state_id}{$trans_id}{constraints}{$var_id}||=[]}, @constraints
                    if @constraints;

                push @{$edges{$state_id}{$trans_id}{field_filters}{$var_id}||=[]}, @filters
                    if @filters;

                $edges{$state_id}{$trans_id}{defaults}{$var_id} = \@defaults
                    if @defaults > 1;

                $edges{$state_id}{$trans_id}{defaults}{$var_id} = $defaults[0]
                    if @defaults == 1;

                @{$edges{$state_id}{$trans_id}{msgs}{invalid}{field}{$var_id}||={}}{keys %invalid_messages} 
                    = values %invalid_messages;

                $edges{$state_id}{$trans_id}{msgs}{missing}{field}{$var_id} = $missing_message
                    if $missing_message;

                # what about $edges{$state_id}{$trans_id}{msgs}{invalid}{default}
                #        and $edges{$state_id}{$trans_id}{msgs}{missing}{default}  ?
            }

            # now <group/>s
            foreach my $group ($xp -> findnodes('../gst:group|gst:group', $transition)) {

                my $group_id = "".$xp -> findvalue('@id', $group);
                next unless $group_id;

                # with <constraint/>s
                my @constraints;

                my @variables = map { $group_id . "." . $xp -> findvalue('@id', $_) }
                                    ($xp -> findnodes('gst:variable', $group));

                foreach my $con ($xp -> findnodes('gst:constraint', $group)) {
                    my $con_id = "".$xp -> findvalue('@id', $con);
                    next unless $con_id;

                    push @constraints, {
                        params => \@variables,
                        constraint => $con_id,
                    };
                }

                push @{$edges{$state_id}{$trans_id}{constraints}{$variables[0]}||=[]}, @constraints
                    if @constraints;

                my $some = $xp -> findvalue('@some', $group);
                next unless $some;

                # now handle <group/>s with @some
                $edges{$state_id}{$trans_id}{require_some}{$group_id} = [ $some, @variables ];
            }

            # now transition-global <filter/>s
            my @filters = map { "".$xp -> findvalue('@id', $_) } ($xp -> findnodes('gst:filter|../gst:filter|../../gst:filter', $transition));
            $edges{$state_id}{$trans_id}{filters} = \@filters if @filters;

            # now handle error msgs
            # $edges{$state_id}{$trans_id}{msgs} = ...
            #   {msgs}{format}

            if(exists $edges{$state_id}{$trans_id}{msgs}) {
                $edges{$state_id}{$trans_id}{msgs}{format} = $error_format;
                $edges{$state_id}{$trans_id}{msgs}{prefix} = $error_prefix;
            }

        } # foreach my $transition
    } # foreach my $state

    @isa = qw(Gestinanna::XSM::Base) unless @isa;

    #warn Data::Dumper -> Dump([\@isa, \%hasa, \%views, \%aliases, \%edges],
    #                           [qw(@isa %hasa %views %aliases %edges)]);

#    { no strict 'refs';
#
#        *{"${package}::ISA"} = \@isa;
#        *{"${package}::HASA"} = \%hasa;
#        *{"${package}::VIEWS"} = \%views;
#        *{"${package}::ALIASES"} = \%aliases;
#        *{"${package}::EDGES"} = \%edges;
#    }

#    return $package;
    return {
        isa => \@isa,
        hasa => \%hasa,
        views => \%views,
        aliases => \%aliases,
        edges => \%edges,
        code => $code, # for those parts that require some code
    };
} # sub compile_data


####
# SAX Parser
####

package Gestinanna::XSM::SAXParser;

use XML::LibXML 1.30;
use XML::LibXSLT;
use Gestinanna::XSM::LibXMLSupport;

sub new {
    my ($type, %self) = @_; 
    return bless { %self } => $type;
}

sub parse {
    my ($self, $thing) = @_;

    my $doc;

    my $parser = XML::LibXML->new();
    #warn "Doc: [$thing]\n";
    if (ref($thing) ne 'XML::LibXML::Document') {
        local($XML::LibXML::match_cb, $XML::LibXML::open_cb,
              $XML::LibXML::read_cb, $XML::LibXML::close_cb);
        Gestinanna::XSM::LibXMLSupport->reset($parser);
        $parser->expand_entities(1);
        eval { 
	    $parser->line_numbers(1);
            #AxKit::Debug(6,"enabled line numbers");
        }; # if $self->{Handler}->{SM_Debug};

        if (ref($thing)) {
            $doc = $parser->parse_fh($thing);
        }
        else {
            $doc = $parser->parse_string($thing);
        }
        #AxKit::Debug(10, 'SM: Parser returned doc');
        $doc->process_xinclude;
    } else {
        $doc = $thing;
    }

    # we want to handle xslt transforms here
    # collect all the pis <?xml-stylesheet file="" type="xslt"?>
    my $root = $doc -> getDocumentElement;
    my $pis = $root -> findnodes('//processing-instruction()');
    my $xslt_parser = XML::LibXSLT -> new();
    foreach my $pi ($pis -> get_nodelist) {
        # go through each transform, looking up the document in the xslt object type in the factory object
        my $data = $pi -> getData();
        my ($filename, $type);
        if($data =~ m{\bfile=(["'])(.*?)\1}) {
            $filename = $2;
        }
        if($data =~ m{\btype=(["'])(.*?)\1}) {
            $type = $2;
        }
        #warn "Looking for $type:$filename\n";
        next unless $type eq 'xslt';
        my $transform = $self -> {factory} -> new(xslt => (object_id => $filename));
        next unless $transform -> is_live;
        my $xslt;
        eval { $xslt = $parser -> parse_string($transform -> data); };
        if($@) {
            warn "Error parsing $filename: $@\n";
            next;
        }
        $transform = undef; # free memory
        $xslt = $xslt_parser -> parse_stylesheet($xslt);
        my $results = $xslt -> transform($doc);
        $doc = $results if $results;
        warn "Doc: [" . $doc -> toString . "]\n";
    }

    my $encoding = $doc->getEncoding() || 'UTF-8';
    my $document = { Parent => undef };
    $self->{Handler}->start_document($document);

    $root = $doc->getDocumentElement;
    if ($root) {
        process_node($self->{Handler}, $root, $encoding);
    }

    $self->{Handler}->end_document($document);
}

sub process_node {
    my ($handler, $node, $encoding) = @_;

    my $lineno = eval { $node->lineNumber; }; # if $handler->{SM_Debug};

    my $node_type = $node->getType();
    if ($node_type == XML_COMMENT_NODE) {
        $handler->comment( { Data => $node->getData, LineNumber => $lineno } );
    }
    elsif ($node_type == XML_TEXT_NODE || $node_type == XML_CDATA_SECTION_NODE) {
        # warn($node->getData . "\n");
        $handler->characters( { Data => encodeToUTF8($encoding,$node->getData()), LineNumber => $lineno } );
    }
    elsif ($node_type == XML_ELEMENT_NODE) {
        # warn("<" . $node->getName . ">\n");
        process_element($handler, $node, $encoding);
        # warn("</" . $node->getName . ">\n");
    }
    elsif ($node_type == XML_ENTITY_REF_NODE) {
        foreach my $kid ($node->getChildnodes) {
            # warn("child of entity ref: " . $kid->getType() . " called: " . $kid->getName . "\n");
            process_node($handler, $kid, $encoding);
        }
    }
    elsif ($node_type == XML_DOCUMENT_NODE) {
        # just get root element. Ignore other cruft.
        foreach my $kid ($node->getChildnodes) {
            if ($kid->getType() == XML_ELEMENT_NODE) {
                process_element($handler, $kid, $encoding);
                last;
            }
        }
    }
    elsif ($node_type == XML_XINCLUDE_START || $node_type == XML_XINCLUDE_END) {
    	# ignore
    }
    else {
        warn("unknown node type: $node_type");
    }
}

sub process_element {
    my ($handler, $element, $encoding) = @_;

    no warnings; # we might have undef'd values here

    my @attr;
    my $debug = $handler->{SM_Debug};

    foreach my $attr ($element->getAttributes) {
        my $lineno = eval { $attr->lineNumber; }; # if $debug;
        if ($attr->getName) {
            push @attr, {
                Name => encodeToUTF8($encoding,$attr->getName),
                Value => encodeToUTF8($encoding,$attr->getData),
                NamespaceURI => encodeToUTF8($encoding,$attr->getNamespaceURI),
                Prefix => encodeToUTF8($encoding,$attr->getPrefix),
                LocalName => encodeToUTF8($encoding,$attr->getLocalName),
                LineNumber => $lineno,
            };
        }
        else {
            push @attr, {
                Name => "xmlns",
                Value => "",
                NamespaceURI => "",
                Prefix => "",
                LocalName => "",
                LineNumber => $lineno,
            };
        }
    }

    my $lineno = eval { $element->lineNumber; }; # if $debug;
    my $node = {
        Name => encodeToUTF8($encoding,$element->getName),
        Attributes => \@attr,
        NamespaceURI => encodeToUTF8($encoding,$element->getNamespaceURI),
        Prefix => encodeToUTF8($encoding,$element->getPrefix),
        LocalName => encodeToUTF8($encoding,$element->getLocalName),
        LineNumber => $lineno,
        Namespaces => { map { $_ -> getPrefix() => $_ -> getNamespaceURI() } $element -> getNamespaces },
    };

    $handler->start_element($node);

    foreach my $child ($element->getChildnodes) {
        process_node($handler, $child, $encoding);
    }

    $handler->end_element($node);
}

####
# SAX Handler
####

package Gestinanna::XSM::SAXHandler;

our @ISA = qw(Gestinanna::XSM);

sub new_handler {
    my($type, %params) = @_;

    return bless { %params } => $type;
}

sub start_expr {
}

sub end_expr {
}

sub manage_text {
}

sub depth {
}

sub current_element {
}

sub location_debug_string {
    my ($e, $file, $line) = @_;
    #return '' if !$e->{SM_Debug} || defined $file && $file =~ m/^Gestinanna::XSM::Core::/;
    (undef, $file, $line) = caller if (@_ < 3);
    $file =~ s/"/''/;
    $file =~ s/\n/ /;
    return '';
    return "\n# line $line \"Perl generated by $file\"\n";
}

sub start_document {
    my $e = shift;
    $e -> reset_state('chars');
    #$e -> reset_state('script');
    $e -> append_state('script', join("\n",
        $e -> location_debug_string,
    ) );

    foreach my $ns (keys %Gestinanna::XSM::tag_lib) {
        my $pkg = $Gestinanna::XSM::tag_lib{$ns};
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("start_document")) && ($sub != \&start_document)) {
            $e -> append_state('script', $e->location_debug_string("${pkg}::start_document",1).$sub->($e));
        }
        elsif ($sub = $pkg->can("parse_init")) {
            $e-> append_state('script', $e->location_debug_string("${pkg}::parse_init",1).$sub->($e));
        }
    }
}

sub end_document {
    my $e = shift;

    $e -> reset_state('chars');
    foreach my $ns (keys %Gestinanna::XSM::tag_lib) {
        my $pkg = $Gestinanna::XSM::tag_lib{$ns};
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("end_document")) && ($sub != \&end_document)) {
            $e-> append_state('script', $e->location_debug_string("${pkg}::end_document",1).$sub->($e));
        }
        elsif ($sub = $pkg->can("parse_final")) {
            $e-> append_state('script', $e->location_debug_string("${pkg}::parse_final",1).$sub->($e));
        }
    }

    return $e->state('script');
}

sub start_element {
    my($e, $element) = @_;

    $e -> {SM_chars} = 0;

    $element -> {Parent} ||= $e -> {Current_Element};
    $element -> {Namespaces} = { %{$element -> {Parent} -> {Namespaces} || {}}, 
                                 %{$element -> {Namespaces}} };

    $e -> {Current_Element} = $element;

    my $ns = $element -> {NamespaceURI};

    my @attribs;

    for my $attr (@{$element->{Attributes}}) {
        if ($attr->{Name} eq 'xmlns') {
            unless (Gestinanna::XSM::is_sm_namespace($attr->{Value})) {
                $e->{Current_NS}{'#default'} = $attr->{Value};
            }
        }
        elsif ($attr->{Name} =~ /^xmlns:(.*)$/) {
            my $prefix = $1;
            unless (Gestinanna::XSM::is_sm_namespace($attr->{Value})) {
                $e->{Current_NS}{$prefix} = $attr->{Value};
            }
        }
        else {
            push @attribs, $attr;
        }
    }

    $element->{Attributes} = \@attribs;

    if (!defined($ns) || 
        !exists($Gestinanna::XSM::tag_lib{ $ns })) 
    {
        $e->manage_text(0); # set default for non-xsp tags
        $e -> append_state('script', Gestinanna::XSM::DefaultHandler::start_element($e, $element));
    }
    else {
#        local $^W;
        $element->{Name} =~ s/^(.*)://;
        my $prefix = $1;
        my $tag = $element->{Name};
        my %attribs;
        # this is probably a bad hack to turn xsp:name="value" into name="value"
        for my $attr (@{$element->{Attributes}}) {
            $attr->{Name} =~ s/^\Q$prefix\E:// if defined $prefix;
            $attribs{$attr->{Name}} = $attr->{Value};
        }
        $e->manage_text(1); # set default for xsp tags
        my $pkg = $Gestinanna::XSM::tag_lib{ $ns };
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("start_element")) && ($sub != \&start_element)) {
            $e -> append_state('script', $e->location_debug_string("${pkg}::start_element",1).$sub->($e, $element));
        }
        elsif ($sub = $pkg->can("parse_start")) {
            $e->append_state('script', $e->location_debug_string("${pkg}::parse_start",1).$sub->($e, $tag, %attribs));
        }
    }
}

sub end_element {
    my $e = shift;
    my $element = shift;
    $e->reset_state('chars');

    my $ns = $element->{NamespaceURI};
    
#    warn "END-NS: $ns : $_[0]\n";
    
    if (!defined($ns) || 
        !exists($Gestinanna::XSM::tag_lib{ $ns })) 
    {
        $e->append_state('script', Gestinanna::XSM::DefaultHandler::end_element($e, $element));
    }
    else {
#        local $^W;
        $element->{Name} =~ s/^(.*)://;
        my $tag = $element->{Name};
        my $pkg = $Gestinanna::XSM::tag_lib{ $ns };
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("end_element")) && ($sub != \&end_element)) {
            $e->append_state('script', $e->location_debug_string("${pkg}::end_element",1).$sub->($e, $element));
        }
        elsif ($sub = $pkg->can("parse_end")) {
            $e->append_state('script', $e->location_debug_string("${pkg}::parse_end",1).$sub->($e, $tag));
        }
    }
    
    $e->{Current_Element} = $element->{Parent} || $e->{Current_Element}->{Parent};
}

sub characters {
    my $e = shift;
    my $text = shift;
    my $ns = $e->{Current_Element}->{NamespaceURI};

#    warn "CHAR-NS: $ns\n";
    
    if (!defined($ns) || 
        !exists($Gestinanna::XSM::tag_lib{ $ns }) ||
        !$e->manage_text(-1))
    {
        $e->append_state('script', Gestinanna::XSM::DefaultHandler::characters($e, $text));
    }
    else {
        my $pkg = $Gestinanna::XSM::tag_lib{ $ns };
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("characters")) && ($sub != \&characters)) {
            $e->append_state('script', $sub->($e, $text));
        }
        elsif ($sub = $pkg->can("parse_char")) {
            $e->append_state('script', $sub->($e, $text->{Data}));
        }
    }
    $e->enter_state('chars');
}

sub comment {
    my $e = shift;
    my $comment = shift;

    my $ns = $e->{Current_Element}->{NamespaceURI};

    if (!defined($ns) || 
        !exists($Gestinanna::XSM::tag_lib{ $ns })) 
    {
        $e->append_state('script', Gestinanna::XSM::DefaultHandler::comment($e, $comment));
    }
    else {
#        local $^W;
        my $pkg = $Gestinanna::XSM::tag_lib{ $ns };
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("comment")) && ($sub != \&comment)) {
            $e->append_state('script', $sub->($e, $comment));
        }
        elsif ($sub = $pkg->can("parse_comment")) {
            $e->append_state('script', $sub->($e, $comment->{Data}));
        }
    }
}

sub processing_instruction {
    my $e = shift;
    my $pi = shift;

    return;

    my $ns = $e->{Current_Element}->{NamespaceURI};
 
    if (!defined($ns) || 
        !exists($Gestinanna::XSM::tag_lib{ $ns })) 
    {
        $e->{SM_Script} .= Gestinanna::XSM::DefaultHandler::processing_instruction($e, $pi);
    }
    else {
#        local $^W;
        my $pkg = $Gestinanna::XSM::tag_lib{ $ns };
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("processing_instruction")) && ($sub != \&processing_instruction)) {
            $e->{SM_Script} .= $sub->($e, $pi);
        }
        elsif ($sub = $pkg->can("parse_pi")) {
            $e->{SM_Script} .= $sub->($e, $pi->{Target}, $pi->{Data});
        }
    }
}

####
# Functions implementing sm:* processing
####

package Gestinanna::XSM::Core;

our @ISA = qw(Gestinanna::XSM);

our $NS = 'http://ns.gestinanna.org/statemachine';

__PACKAGE__ -> register;

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

my %expression_state = map { $_ => 1 } qw(
    assert
    association
    choose
    considering
    delayed
    dump
    for-each
    goto
    if
    list
    log
    otherwise
    script
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
            $class = $e->{compiler} -> ($attribs{name});
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
            push @{$e -> {SM_FILES}||=[]}, $attribs{name} . "/$1";
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
        if($e -> state('in-script')) {
            $e -> {SM_Variable_select} = defined $attribs{select};
            $e -> enter_state('in-expression');
            $e -> enter_state('in-list');
            my $select = '';
            $select = Gestinanna::XSM::compile_expr($e, $attribs{select}) . "," if defined $attribs{select};
            my $t = "t" . $e -> state('in-expression');
            return '$vars{' . $e -> static_expr($attribs{name}) . "} = do { my \@$t = $select";
        }
        else {
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
        }
        return '';
    }
    elsif ($tag eq 'constraint') {
        $e -> reset_state('params');
        return '';
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
            my $pkg = $Gestinanna::XSM::tag_lib{$tns};
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
        if($e -> enter_state('in-script') > 1) {
            $e -> push_state;
            $e -> reset_state('in-expression');
            return "sub { \n";
        }

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
    #$ret .= <<1HERE1;
    #warn "Entering " . __PACKAGE__ . "::$sub_name\n";
#1HERE1

        # check to see if script can access the session data or not

        $ret .= <<1HERE1 if exists $attribs{super} && defined $attribs{super} && $attribs{super} eq 'begin';
    {
    my \$state = \$sm -> SUPER::$sub_name;
    return \$state if defined \$state;
    }
1HERE1
        return $ret;
    }
    elsif ($tag eq 'delayed') {
        $e -> push_state;
        $e -> reset_state('is-expression');
        return 'Apache -> request -> post_connection(sub {';
    }
    elsif ($tag eq 'log') {
        require Apache::Log;
        $e -> enter_state('in-expression');
        $e -> enter_state('in-list');
        $e -> enter_state('in-text');
        my $level = $e -> static_expr($attribs{level});
        #$level = 'debug' unless $level =~ m{^(emerg|alert|crit|error|warn|notice|info|debug)$};
        return "\$sm -> log($level,";
        #return "Apache -> request -> log -> $level(join(\"\",";
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
        unless($e -> state('in-script')) {
            warn "The choose element may only appear within a script element";
            return '';
        }
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
    #elsif ($tag eq 'comment') {
    #    return '# ';
    #}
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
            #$e -> push_state;
            #$e -> enter_state('in-goto');
            #$e -> reset_state('in-expression');
            #my $a = '%goto' . $e -> state('in-goto');
            #$code .= ", args => do { my $a;";
            #return $code; # . ")" . $e -> semi;
        }
        if($attribs{state}) {
            my $state = $e -> static_expr($attribs{state});
            return "return ( ($state)[0] )" . $e -> semi;
        }
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
        if($e -> state('in-script')) {
            my $t = "t" . $e -> state('in-expression');
            $e -> leave_state('in-expression');
            $e -> leave_state('in-list');
            return "; scalar(\@$t) > 1 ? \\\@$t : \$$t\[0]; }" . $e -> semi;
        }
        else {
            $e -> reset_state('variable-id');
        }
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
            my $pkg = $Gestinanna::XSM::tag_lib{$tns};
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
            push @code, <<1HERE1;
{
    constraint => $constraint,
    params => [ $params ],
}
1HERE1
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
        return "}" . $e -> semi if $e -> state('in-script');
        return <<1HERE1 if defined $script_super && $script_super eq 'end';
    {
    my \$state = \$sm -> SUPER::$sub_name;
    return \$state if defined \$state;
    }
    return;
}
1HERE1
        return " return;\n}\n";
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
        return ')' . $e -> semi;
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
            return <<1HERE1;
push $l, ( do { 
    unshift \@{\$sm -> {script_data} -> {position} ||= []}, -1; 
    my \@_b = ($array); 
    unshift \@{\$sm -> {script_data} -> {last} ||= []}, scalar(\@_b) - 1; 
    my \@_a = map { $body } (\@_b); 
    shift \@{\$sm -> {script_data} -> {position}}; 
    shift \@{\$sm -> {script_data} -> {last}}; 
    \@_a; 
} );
1HERE1
        }
        if($e -> state('in-expression')) {
            return <<1HERE1;
do { 
    unshift \@{\$sm -> {script_data} -> {position} ||= []}, -1; 
    my \@_b = ($array); 
    unshift \@{\$sm -> {script_data} -> {last} ||= []}, scalar(\@_b) - 1; 
    my \@_a = map { $body } (\@_b); 
    shift \@{\$sm -> {script_data} -> {position}}; 
    shift \@{\$sm -> {script_data} -> {last}}; 
    \@_a; 
}
1HERE1
        }
        return <<1HERE1;
unshift \@{\$sm -> {script_data} -> {position} ||= []}, -1; 
my \@_b = ($array);
unshift \@{\$sm -> {script_data} -> {last} ||= []}, scalar(\@_b) - 1;
foreach (\@_b) { 
    $body 
}
shift \@{\$sm -> {script_data} -> {position}};
shift \@{\$sm -> {script_data} -> {last}};
1HERE1
    }
    elsif ($tag eq 'choose') {
        return '' unless $e -> state('in-script');
        my $script = $e -> state('script');
        my $o = $e -> state('choose-otherwise');
        $e -> pop_state;
        if($e -> state('in-expression')) {
            if($o) {
                return "$script $o )";
            }
            return "$script () )";
        }
        $script .= " } else { $o }";
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
    elsif ($tag eq 'assert') {
        my $state = $e -> static_expr($attribs{state});
        my $script = $e -> state('script');
        $e -> pop_state;
        $e -> set_state('script', $script);
        return "return $state; }" . $e -> semi;
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
    #elsif($tag eq 'comment') {
    #    return "\n";
    #}
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



package Gestinanna::XSM::DefaultHandler;

*makeSingleQuoted = \&Gestinanna::XSM::makeSingleQuoted;

sub _undouble_curlies {
    my $value = shift;
    $value =~ s/\{\{/\{/g;
    $value =~ s/\}\}/\}/g;
    return $value;
}

sub _attr_value_template {
    my ($e, $value) = @_;

    return '';
}

sub start_element {
    my ($e, $node) = @_;

    return '';
}

sub end_element {
    my ($e, $element) = @_;

    return '';
}

sub characters {
    my ($e, $node) = @_;

    return '';
}

sub comment {
    return '';
}

sub processing_instruction {
    return '';
}

package Gestinanna::XSM::Op;

# used to preemptively do something else
sub throw {
    my($class, %params) = @_;

    if(@_ > 1) {
        if(ref $class) {
            $params{op} ||= $class -> {op};
        }
        $class = ref $class || $class;
        my $self = bless { } => $class;

        $self -> {op} = $params{op};
        $self -> {arg} = $params{arg};

#        Carp::cluck "Throwing $params{op}\n";
        die $self;
    }
    use Carp ();
#    Carp::cluck "Rethrowing " . $class -> {op} . "\n" if ref $class;
    die $class if ref $class;
    die bless { op => 'noop', args => { } } => $class;
}

sub op { return $_[0] -> {op}; }

sub arg { return $_[0] -> {arg} -> {$_[1]}; }

sub AUTOLOAD {
    our $AUTOLOAD;
    my $class = shift;
    return if ref $class;
    
    my($op) = $AUTOLOAD =~ /::([^:]+)$/;
    
    return if $op eq 'DESTROY';
    
    my $self = bless { } => $class;

    $self -> {op} = $op;
    $self -> {arg} = { @_ };

#    Carp::cluck "Throwing $op\n";
    die $self;
}


1;

__END__

=head1 NAME

Gestinanna::XSM - eXtensible State Machines

=head1 SYNOPSIS

 $sub_code = $compiler -> compile_script($xml);

 eval "package $run_time_package; $sub_code";

=head1 DESCRIPTION

 
