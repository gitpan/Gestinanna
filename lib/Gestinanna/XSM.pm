package Gestinanna::XSM;

use File::Spec::Unix;
use Gestinanna::XSM::Base;
use Gestinanna::XSM::DefaultHandler;
use Gestinanna::XSM::Expression::Parser;
use Storable;

use strict;

use utf8;

use Carp ();

sub register {
    my $class = shift;
    Carp::carp "${class} -> register is deprecated\n";
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

    return $ns eq $Gestinanna::XSM::StateMachine::NS; #"http://ns.gestinanna.org/statemachine";
}

sub ns_handler {
    my($self, $ns) = @_;

    return unless exists $self -> {namespaces} -> {$ns};
    return $self -> {namespaces} -> {$ns};
}

sub handled_namespaces {
    my $self = shift;

    return grep { defined $self -> {namespaces} -> {$_} }
                keys %{$self -> {namespaces} || {}};
}

sub semi { $_[0] -> state('in-expression') ? ($_[0] -> state('in-list') ? ',' : '') : ';'; }

sub push_state {
    my $e = shift;

    push @{$e -> {SM_State_Stack} ||= [ ]}, $e -> {SM_State};

    $e -> {SM_State} = Storable::dclone($e -> {SM_State} || {}); # copy
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
    #warn "$class -> compile with params: ", join(", ", keys %params), "\n";

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

    $to_eval = 'use vars qw(' . join(" ", @{$params{'vars'}||[]}) . ");\n"
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
        #warn "Doc: [" . $doc -> toString . "]\n";
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
        NamespaceHandlers => $handler -> {NamespaceHandlers},
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

    foreach my $ns ($e -> handled_namespaces) {
        my $pkg = $e -> ns_handler($ns);
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
    foreach my $ns ($e -> handled_namespaces) {
        my $pkg = $e -> ns_handler($ns);
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

sub start_script { return ''; }
sub end_script { return ''; }

sub get_script_start {
    my $e = shift;

    my $ret = '';
    foreach my $ns ($e -> handled_namespaces) {
        my $pkg = $e -> ns_handler($ns);
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("start_script")) && ($sub != \&start_script)) {
            $ret .= $e->location_debug_string("${pkg}::start_script",1).$sub->($e);
        }
    }
    return $ret;
}

sub get_script_end {
    my $e = shift;

    my $ret = '';
    foreach my $ns ($e -> handled_namespaces) {
        my $pkg = $e -> ns_handler($ns);
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("end_script")) && ($sub != \&end_script)) {    
            $ret .= $e->location_debug_string("${pkg}::end_script",1).$sub->($e);                       
        }
    }
    return $ret;
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
        !defined $e -> ns_handler($ns))
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
        my $pkg = $e -> ns_handler($ns); 
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
    my $pkg = $e -> ns_handler($ns);
    
#    warn "END-NS: $ns : $_[0]\n";
    
    if (!defined($ns) || 
        !defined($pkg))
    {
        $e->append_state('script', Gestinanna::XSM::DefaultHandler::end_element($e, $element));
    }
    else {
#        local $^W;
        $element->{Name} =~ s/^(.*)://;
        my $tag = $element->{Name};
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

    #warn "CHAR-NS: $ns\n";
    my $pkg = $e -> ns_handler($ns);
    

    if (!defined($ns)  || 
        !defined($pkg)# ||
        #!$e->manage_text(-1)
    )
    {
        $e->append_state('text', Gestinanna::XSM::DefaultHandler::characters($e, $text));
    }
    else {
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("characters")) && ($sub != \&characters)) {
            $e->append_state('text', $sub->($e, $text));
        }
        elsif ($sub = $pkg->can("parse_char")) {
            $e->append_state('text', $sub->($e, $text->{Data}));
        }
    }
    $e->enter_state('chars');
}

sub comment {
    my $e = shift;
    my $comment = shift;

    my $ns = $e->{Current_Element}->{NamespaceURI};
    my $pkg = $e -> ns_handler($ns);

    if (!defined($ns) || 
        !defined($pkg))
    {
        $e->append_state('script', Gestinanna::XSM::DefaultHandler::comment($e, $comment));
    }
    else {
#        local $^W;
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
    my $pkg = $e -> ns_handler($ns);
 
    if (!defined($ns) || 
        !defined($pkg))
    {
        $e->append_state('script', Gestinanna::XSM::DefaultHandler::processing_instruction($e, $pi));
    }
    else {
#        local $^W;
        my $sub;
        local $Gestinanna::XSM::TaglibPkg = $pkg;
        if (($sub = $pkg->can("processing_instruction")) && ($sub != \&processing_instruction)) {
            $e->append_state('script', $sub->($e, $pi));
        }
        elsif ($sub = $pkg->can("parse_pi")) {
            $e->append_state('script', $sub->($e, $pi->{Target}, $pi->{Data}));
        }
    }
}

1;

__END__
