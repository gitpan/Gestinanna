#!/usr/local/bin/perl

eval 'exec /usr/local/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#
# yapp -- Front end to the Parse::Yapp module
#
# (c) Copyright 1998-2001 Francois Desarmenien, all rights reserved.
# (see the pod text in Parse::Yapp module for use and distribution rights)
#
#

# converted to handle the Gestinanna XSM expression parser so we don't 
# depend on install paths for scripts

require 5.004;

use File::Basename;
use Getopt::Std;
use Config;

BEGIN {
    eval "require Parse::Yapp;";
    if($@) {
        warn "You will need to install Parse::Yapp before you can regenerate\nthe XSM Expression Parser.\n";
        exit 0;
    }
}

use strict;

use vars qw ( $opt_n $opt_m $opt_V $opt_v $opt_o $opt_h $opt_s $opt_t $opt_b);

sub Usage {
	my($prog)=(fileparse($0,'\..*'))[0];
	die <<EOF;

Usage:	$prog [options] grammar[.yp]
  or	$prog -V
  or	$prog -h

    -m module   Give your parser module the name <module>
                default is <grammar>
    -v          Create a file <grammar>.output describing your parser
    -s          Create a standalone module in which the driver is included
    -n          Disable source file line numbering embedded in your parser
    -o outfile  Create the file <outfile> for your parser module
                Default is <grammar>.pm or, if -m A::Module::Name is
                specified, Name.pm
    -t filename Uses the file <filename> as a template for creating the parser
                module file.  Default is to use internal template defined
                in Parse::Yapp::Output
    -b shebang  Adds '#!<shebang>' as the very first line of the output file

    grammar     The grammar file. If no suffix is given, and the file
                does not exists, .yp is added

    -V          Display current version of Parse::Yapp and gracefully exits
    -h          Display this help screen

EOF
}

$opt_o = 'lib/Gestinanna/XSM/Expression/Parser.pm';
$opt_s = 1;
$opt_m = 'Gestinanna::XSM::Expression::Parser';

my($filename)='parser.yp';
my($base,$path,$sfx)=fileparse($filename,'\..*');

#	-r "$filename"
#	or do {
#		$sfx eq '.yp'
#	or	$filename.='.yp';
#
#		-r "$filename"
#	or	die "Cannot open $filename for reading.\n";
#};

my $input;
{ local($/) = undef;
  $input = <DATA>;
}

#my($parser)=new Parse::Yapp(inputfile => $filename);
my($parser)=new Parse::Yapp(input => $input);

my($warnings)=$parser->Warnings();

	$warnings
and	print STDERR $warnings;

	$opt_v
and	do {
	my($output)="$path$base.output";
	my($tmp);

		open(OUT,">$output")
	or	die "Cannot create $base.output for writing.\n";

		$tmp=$parser->Warnings()
	and	print	OUT "Warnings:\n---------\n$tmp\n";
		$tmp=$parser->Conflicts()
	and	print	OUT "Conflicts:\n----------\n$tmp\n";
	print	OUT "Rules:\n------\n";
	print	OUT $parser->ShowRules()."\n";
	print	OUT "States:\n-------\n";
	print	OUT $parser->ShowDfa()."\n";
	print	OUT "Summary:\n--------\n";
	print	OUT $parser->Summary();

	close(OUT);
};

my($outfile)="$path$base.pm";
my($package)="$base";

	$opt_m
and	do {
    $package=$opt_m;
    $package=~/^(?:(?:[^:]|:(?!:))*::)*(.*)$/;
    $outfile="$1.pm";
};

	$opt_o
and	$outfile=$opt_o;

$opt_s = $opt_s ? 1 : 0;

$opt_n = $opt_n ? 0 : 1;

	open(OUT,">$outfile")
or	die "Cannot open $outfile for writing.\n";

    defined($opt_b)
and do {
        $opt_b
    or  $opt_b = $Config{perlpath};
    print OUT "#!$opt_b\n";
};

print OUT $parser->Output(classname  => $package,
                          standalone => $opt_s,
                          linenumbers => $opt_n,
                          template    => $opt_t,
                         );


close(OUT);
__END__
## Grammar by James Clark.  Funky Perl by Barrie Slaymaker
## Additional Perl code by James G. Smith
#
# Grammar copied from a message on the xsl-list:
#   Subject: Re: New XSLT draft
#   From: James Clark <jjc@jclark.com>
#   Date: Mon, 12 Jul 1999 09:03:55 +0700


%{
    use Carp;
    use UNIVERSAL;
    use Gestinanna::XSM::Expression;

    sub _no {
        my $p = shift;
        push @{$p->{USER}->{NONONO}}, join(
            "",
            "XSM expression construct not supported: ",
            join( " ", @_),
            " (grammar rule at ",
            (caller)[1],
            ", line ",
            (caller)[2],
            ")"
        );

        return ();
    }

    sub _step {
        my @ops = grep $_, @_;

        for ( 0..$#ops-1 ) {
            $ops[$_]->set_next( $ops[$_+1] );
        }
            
        return $ops[0];
    }
%}

%token QNAME
/* %token NAME_COLON_STAR */
%token DOT
%token DOT_DOT
%token RANGE
%token AT
%token AXIS_NAME
%token AXIS_METHOD
%token FUNCTION_NAME
/* 
%token COMMENT 
%token PI
%token TEXT
%token NODE
*/
%token STAR
%token LPAR
%token RPAR
%token LSQB
%token RSQB
%token LCRL
%token RCRL
%token LITERAL
%token NUMBER
%token COLON_COLON
%token DOLLAR_QNAME
%token SLASH
%token SLASH_SLASH
%token VBAR
%token COMMA
%token PLUS
%token MINUS
%token EQUALS
%token GT
%token LT
%token GTE
%token LTE
%token MULTIPLY
%token AND
%token OR
%token MOD
%token DIV
# %token QUO

## We also catch some Perl tokens so we can give useful advice
%token EQUALS_EQUALS
%token VBAR_VBAR
%token AMP_AMP

%%

## NOTE: I use the paren-less format for Perl subcalls here so that
## perl will warn me if I don't have one defined.

expr :
    or_expr
    | range_expr
    ;

or_expr :
    and_expr
    | or_expr OR and_expr                  { '(' . $_[1] . ') || (' . $_[3] . ')' }
    | or_expr VBAR_VBAR and_expr           {
        die "DPath uses 'or' instead of Perl's '||'\n";
    }
    ;

and_expr :
    equality_expr
    | and_expr AND equality_expr           { '(' . $_[1] . ') && (' . $_[3] . ')' }
    | and_expr AMP_AMP equality_expr       {
        die "DPath uses 'and' instead of Perl's '&&'\n";
    }
    | and_expr AMP equality_expr       {
        die "DPath uses 'and' instead of Perl's '&'\n";
    }
    ;

equality_expr :
    relational_expr
    | equality_expr EQUALS relational_expr      { '(0 == Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
    | equality_expr BANG_EQUALS relational_expr { '(0 != Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
    | equality_expr EQUALS_EQUALS relational_expr { 
        die "XSM expressions use '=' instead of Perl's '=='\n";
    }
    ;

relational_expr :
    additive_expr
    | relational_expr LT additive_expr    { '(0 > Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
    | relational_expr GT additive_expr    { '(0 < Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
    | relational_expr LTE additive_expr   { '(0 >= Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
    | relational_expr GTE additive_expr   { '(0 <= Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
    ;

range_expr :
    additive_expr RANGE additive_expr { "Gestinanna::XSM::Expression::xsm_range(($_[1])[0], ($_[3])[0])" }
    ;

additive_expr :
    multiplicative_expr
    | additive_expr PLUS multiplicative_expr  { '(' . $_[1] . ') + (' . $_[3] . ')' }
    | additive_expr MINUS multiplicative_expr { '(' . $_[1] . ') - (' . $_[3] . ')' }
    ;

multiplicative_expr :
    unary_expr
    | multiplicative_expr MULTIPLY unary_expr { '(' . $_[1] . ') * (' . $_[3] . ')' }
    | multiplicative_expr DIV unary_expr      { '(' . $_[1] . ') / (' . $_[3] . ')' } 
    | multiplicative_expr MOD unary_expr      { '(' . $_[1] . ') % (' . $_[3] . ')' }
    ;

unary_expr :
    union_expr
    | MINUS unary_expr                        { '-(' . $_[2] . ')'  }
    ;

union_expr :
    path_expr
    | union_expr_x                       { '[ ' . $_[1] . ' ]' }
    ;

union_expr_x :
    path_expr VBAR path_expr               { "($_[1]),($_[3])" }
    | union_expr_x VBAR path_expr          { "$_[1],($_[3])" }
    ;

path_expr :
    location_path
    | primary_expr predicates segment    { no warnings; $_[3] . ' ' . $_[2] . ' (' . $_[1] . ')'; }
    ;

segment :
    /* empty */
    | SLASH relative_location_path        { $_[2] }
    | SLASH_SLASH relative_location_path  { "grep { defined } map { map { $_[2] } Gestinanna::XSM::Expression::axis_descendent_or_self(\$_, '*') } " }
    ;

location_path :
    relative_location_path { ($_[1] =~ m{\$topic$}) ? $_[1] : $_[1] . ' $topic ' }
    | absolute_location_path
    ;

absolute_location_path :
    SLASH                                { '$data{"local"}' }
    | SLASH relative_location_path       { $_[2] . ' $data{"local"}' }
    | SLASH_SLASH relative_location_path { $_[2] . ' Gestinanna::XSM::Expression::axis_descendent_or_self($data{"local"},"*")' }
    | AXIS_NAME COLON_COLON SLASH relative_location_path { $_[4] . " \$data{\"\Q$_[1]\E\"}" }
    | AXIS_NAME COLON_COLON SLASH_SLASH relative_location_path { $_[4] . "Gestinanna::XSM::Expression::axis_descendent_or_self(\$data{\"\Q$_[1]\E\"},'*')" }
    ;

relative_location_path :
    step
    | relative_location_path SLASH step    { $_[3] . ' ' . $_[1] }  #{ [ 'step-child', @_[1,3] ] }
    ## This next rule means that the grammar does not like "////" :(.
    ## TODO: add a rule for successive "//" paths
    #| relative_location_path SLASH_SLASH step { [ 'step-descendent', @_[1,3] ] }
    | relative_location_path SLASH_SLASH step { $_[3] . ' grep { defined } map { Gestinanna::XSM::Expression::axis_descendent_or_self($_, "*") } ' . $_[1] }
    ;

step :
    axis node_test predicates         { 
        my($axis, $node_test, $predicates) = @_[1..$#_];
        return "" unless defined $node_test;  # is this correct?
        $axis = "child" unless defined $axis;
        $axis =~ tr/-/_/;
        $predicates = "" unless defined $predicates;
        return qq{$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_$axis(\$_, "\Q$node_test\E") }};
    }
    | axis LCRL DOLLAR_QNAME RCRL predicates {
        my($axis, $dqname, $predicates) = @_[1,3,5..$#_];
        return "" unless defined $dqname;  # is this correct?   
        $axis = "child" unless defined $axis;
        $axis =~ tr/-/_/;
        $predicates = "" unless defined $predicates;
        return qq{$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_$axis(\$_, \$vars{"\Q$dqname\E"}) }};
    }
    | AXIS_METHOD COLON_COLON node_test predicates {
        my($node_test, $predicates) = @_[3,4];
        return "" unless defined $node_test;  # is this correct?
        $predicates = "" unless defined $predicates;
        return qq{$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_method(\$_, "\Q$node_test\E") }};
    }
    | AXIS_METHOD COLON_COLON FUNCTION_NAME LPAR opt_args RPAR predicates {
        my($node_test, $args, $predicates) = @_[3, 5, 7];
        return "" unless defined $node_test;  # is this correct?
        $predicates = "" unless defined $predicates;
        return qq[$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_method(\$_, "\Q$node_test\E", (] 
               . join("),(", @{$args||[]}) . ')) }';
    }
    | DOT                             { '$topic' }  # current selection
    | DOT_DOT { _no @_; }
    ;

#    | FUNCTION_NAME LPAR opt_args RPAR predicates {
#        my($node_test, $args, $predicates) = @_[1, 3, 5];
#        $predicates = "" unless defined $predicates;
#        return "" unless defined $node_test;  # is this correct?
#        return qq[$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_method(\$_, "\Q$node_test\E", (]
#               . join("),(", @{$args||[]}) . ')) }';
#    }

axis:
    /* empty */                 { }
    | AXIS_NAME COLON_COLON     { $_[1] }
    | AT                        { 'attribute'}
    ;

predicates :
    /* empty */ { }
    | predicates LSQB expr RSQB { 
        no warnings;
        'grep { local($topic) = $_; ' . $_[3] . ' } ' . $_[1] 
    }
    ;

primary_expr :
    DOLLAR_QNAME     { "\$vars{\"\Q$_[1]\E\"}" }
    | LT expr GT { # expr is expected to be a statement that needs to be called until it returns undef or nothing
       qq{do { my(\@list, \$t, \@t);  push \@list, \$t, \@t while( ((\$t, \@t) = ($_[2])) && defined \$t); \@list; }}
    }
    | LPAR expr RPAR { '(' . $_[2] . ')' }
    | LITERAL { "\"\Q$_[1]\E\"" }
    | NUMBER
    | FUNCTION_NAME LPAR opt_args RPAR { 
          my($name, $args) = @_[1,3];
          my($ns);
          if($name =~ m{:}) {
              ($ns, $name) = split(/:/, $name, 2);
          }
          else {
              $ns = $_[0] -> {USER}{e}{Current_NS}{'#default'};
          }
          # now we need to translate $ns to a namespaceuri
          my $tns = $_[0]->{USER}{e}{Current_Element}{Namespaces}{$ns};
          _no $_[0], "unknown namespace ($ns)" unless defined $tns;
          $name =~ tr/-/_/;
          $name = "xsm_$name";
          my $pkg = $_[0] -> {USER}{e} -> ns_handler($tns);
          _no $_[0], "no namespace handler defined for $ns ($tns)" unless defined $pkg;
          _no $_[0], "no such function $_[1]" unless UNIVERSAL::can($pkg, $name);

          my $proto = prototype "${pkg}::${name}";
          $proto =~ s{^\$}{}; # get rid of statemachine reference
          #warn "prototype: $proto\n";
          #warn "$_[1] ($proto) (" . join("; ", @{$args || []}) . ")\n";
          if($proto) {
              my $code = "${pkg}::${name} (";
              my($n, $p) = (0);
              my(@args) = @{ $args || [] };
              my @pargs;
              while( scalar(@args) && $proto =~ s{^ ( \\?[\$\@\%\*\&] | \; ) }{}x ) {
                  $p = $1;
                  #$proto =~ s{^\Q$p\E}{};
                  #warn "p: [$p] ($n)\n";
                  next if $p eq ';';
                  $n++;
                  if($p eq "\\\@") {
                      push @pargs, '@{[ ' . shift(@args) . ' ]}';
                  }
                  elsif($p eq '@') {
                      if($proto eq '') {
                          push @pargs, map { "\@{[($_)]}" } @args;
                          @args = ( );
                      }
                      else {
                          push @pargs, "(" . shift(@args) . ")";
                      }
                  }
                  elsif($p eq '$') {
                      push @pargs, '( ' . shift(@args) . ' )[0]';
                  }
                  else {
                      push @pargs, '[ ' . shift(@args) . ']';
                  }
              }
              #warn "done - p: [$p] ($n)\n";
              #warn "there are " . scalar(@args) . " arguments left: " . join("; ", @args) . "\n";
              if(@args) {
                  _no $_[0], "found " . (scalar(@{$args||[]})) . " arguments but only expected $n in call to $_[1]";
              }
              elsif($p ne ';' && $proto ne '' && $proto !~ m{^;}) {
                  $n++ while $proto =~ s{^(\\?[\$\@\%\*\&]|\;)}{};
                  _no $_[0], "expected $n arguments but only found " . (scalar(@{$args||[]})) . " in call to $_[1]";
              }
              $code .= join(", ", "\$sm", @pargs) . ')';
              return $code;
          }
          return "${pkg}::${name} (\$sm, (" . join("),(", @{$args||[]}) . '))' if @{$args||[]};
          return "${pkg}::${name} (\$sm)";
      }
    ;

opt_args :
    /* empty */             { [] }
    | args                  ## pass thru
    ;

args :
    expr              { [ $_[1] ] }
    | args COMMA expr { 
        push @{$_[1]}, $_[3];
        $_[1];
    }
    ;
  
node_test :
    QNAME                               { $_[1] }
    | NUMBER
    | STAR                                { '*' }
    ;

%%
#opt_literal :
#    /* empty */
#    | LITERAL { _no @_; }
#    ;


=head1

Data::DPath::Parser - Parses the DPath subset used by Data::DPath

=head1 SYNOPSIS

   use Data::DPath::Parser;

   my $result = Data::DPath::Parser->parse( $xpath );

   $result -> evaluate( $root, $context );

   $sub = $result -> compile;
   $sub -> ( $root, $context );

=head1 DESCRIPTION

Some notes on the parsing and evaluation:

=over

=item *

Result Objects

TODO: change to return sets of references into the data tree

The result expressions alway return true or false.  For DPath
expressions that would normally return a node-set, the result is true if
the current SAX event would build a node that would be in the node set.
No floating point or string return objects are supported (this may
change).

=item *

Context

The DPath context node is the document root.

Not sure what to do about the context position, but the context size is
of necessity undefined.

=back

=head1 DPath Expressions

DPath is based on XPath, but has some subtle (or not-so-subtle) differences.

=head2 Axis

DPath makes use of the following axis:

=over 4

=item ancestor

=item ancestor-or-self

=item attribute

Eventually (with Perl 6), we will be able to support arbitrary 
attributes tied to data objects.  But until then, only the following 
attributes are supported:

=over 4


=item can

 Example: //*[@can="print" and @can="read"]

This will find all the nodes that have C<print> and C<read> methods.

=item defined

 Example: /foo[@defined]

Returns the object C<foo> in the root of the context if it is defined.

=item isa

 Example: //*[@isa="Apache::Upload"]

This will find all the nodes in the context that are 
L<Apache::Upload|Apache::Upload> objects.

=item size

=item version

=back


=item child

This forces the identifier to be a child of a node.  A child may be a 
hash key or an array index, depending on the parent node type.  It will 
not be a method.

=item descendant

=item descendant-or-self 

=item following

=item following-sibling 

=item method

This forces the identifier to be a method of an object.

=item namespace

=item parent

=item preceding

=item preceding-sibling   

=item self

=back

=cut

use Carp;

my %tokens = (qw(
    .           DOT
    ..          DOT_DOT
    @           AT
    *           STAR
    (           LPAR
    )           RPAR
    [           LSQB
    ]           RSQB
    {           LCRL
    }           RCRL
    ::          COLON_COLON
    /           SLASH
    //          SLASH_SLASH
    |           VBAR
    +           PLUS
    -           MINUS
    =           EQUALS
    !=          BANG_EQUALS
    >           GT
    <           LT
    >=          GTE
    <=          LTE

    ==          EQUALS_EQUALS
    ||          VBAR_VBAR
    &&          AMP_AMP
    &           AMP
),
    "," =>      "COMMA"
);

my $simple_tokens =
    join "|",
        map
            quotemeta,
            reverse
                sort {
                    length $a <=> length $b
                } keys %tokens;

my $NCName = "(?:[a-zA-Z_][a-zA-Z0-9_.-]*)"; ## TODO: comb. chars & Extenders

my %EventType = qw(
    node                   NODE
    text                   TEXT
    comment                COMMENT
    processing-instruction PI
);

my $EventType = "(?:" .
    join( "|", map quotemeta, sort {length $a <=> length $b} keys %EventType ) .
    ")";

my $AxisName = "(?:" .  join( "|", split /\n+/, <<AXIS_LIST_END ) . ")" ;
attribute
child
child-or-self
descendant
descendant-or-self
method
self
AXIS_LIST_END
#ancestor
#ancestor-or-self
#following
#following-sibling
#namespace
#parent
#preceding
#preceding-sibling

my $NamespaceName = "(?:" . join( "|", split /\n+/, <<NAMESPACE_LIST_END ) . ")";
context
global
local
session
solar
NAMESPACE_LIST_END

my %preceding_tokens = map { ( $_ => undef ) } ( qw(
    @ :: [
    and or mod div
    *
    / // | + - = != < <= > >=

    == & && ||
    ),
    "(", ",",'$',
) ;


=begin testing

# debugging

is(__PACKAGE__::debugging, 0);

=end testing

=cut

sub debugging () { 0 }

=begin testing

# lex

=end testing

=cut

sub lex {
    my ( $p ) = @_;

    ## Optimization notes: we aren't parsing War and Peace here, so
    ## readability over performance.

    my $d = $p->{USER};
    my $input = \$d->{Input};

    ## This needs to be more contextual, only recognizing axis/function-name
    if ( ( pos( $$input ) || 0 ) == length $$input ) {
        $d->{LastToken} = undef;
        return ( '', undef );
    }

    my ( $token, $val ) ;
    ## First do the disambiguation rules:

    ## If there is a preceding token and the preceding token is not
    ## one of "@", "::", "(", "[", "," or an Operator,
    if ( defined $d->{LastToken}
        && ! exists $preceding_tokens{$d->{LastToken}}
    ) {
        ## a * must be recognized as a MultiplyOperator
        if ( $$input =~ /\G\s*\*/gc ) {
            ( $token, $val ) = ( MULTIPLY => "*" );
        }
        ## an NCName must be recognized as an OperatorName.
        elsif ( $$input =~ /\G\s*($NCName)/gc ) {
            die "Expected and, or, mod or div, got '$1'\n"
                unless 0 <= index "and|or|mod|div", $1;
            ( $token, $val ) = ( ( $1 eq 'and' ? 'AND'
                                 : $1 eq 'or'  ? 'OR'
                                 : $1 eq 'mod' ? 'MOD'
                                 : 'DIV'
                                 ), $1 );
        }
    }

    if( $$input =~ /\G\s*(\.\.)\s/gc ) {
        ( $token, $val ) = ( RANGE => '..' );
    }

    ## NOTE: \s is only an approximation for ExprWhitespace
    unless ( defined $token ) {
        $$input =~ m{\G\s*(?:
            ## If the character following an NCName (possibly after
            ## intervening ExprWhitespace) is (, then the token must be
            ## recognized as a EventType or a FunctionName.
            ((?:$NCName:)?$NCName)\s*(?=\()

            ## If the two characters following an NCName (possibly after
            ## intervening ExprWhitespace) are ::, then the token must be
            ## recognized as an AxisName
            |($NCName)\s*(?=::)

            ## Otherwise, it's just a normal lexer.
            |($NCName:\*)                           #NAME_COLON_STAR
            |((?:$NCName:)?$NCName)                 #QNAME
            |('[^']*'|"[^"]*")                      #LITERAL
            |(-?\d+(?:\.\d+)?|\.\d+)                #NUMBER
            |\$((?:$NCName:)?$NCName)               #DOLLAR_QNAME
            |($simple_tokens)
        )\s*}gcx;

        ( $token, $val ) =
            defined $1 ? ( FUNCTION_NAME    =>  $1 ) :
            defined $2 ? ( ( $2 eq 'method' ? 'AXIS_METHOD' : 'AXIS_NAME' ) =>  $2 ) :
            defined $3 ? ( NAME_COLON_STAR  =>  $3 ) :
            defined $4 ? ( QNAME            =>  $4 ) :
            defined $5 ? ( LITERAL          =>  do {
                    my $s = substr( $5, 1, -1 );
                    $s =~ s/([\\'])/\\$1/g;
                    $s;
                }
            ) :
            defined $6 ? ( NUMBER           =>  $6 ) :
            defined $7 ? ( DOLLAR_QNAME     =>  $7 ) :
            defined $8 ? ( $tokens{$8}      =>  $8 ) :
            die "Failed to parse '$$input' at ",
                pos $$input,
                "\n";
    }

    $d->{LastTokenType} = $token;
    $d->{LastToken} = $val;

    if ( debugging  || $d -> {DEBUG}) {
        warn
            "'",
            substr($$input, pos($$input)),
            "' (",
            pos $$input,
            "):",
            join( " => ", map defined $_ ? $_ : "<undef>", $token, $val ),
            "\n";
    }

    return ( $token, $val );
}

=begin testing

# error

=end testing

=cut

sub error {
    my ( $p ) = @_;
    return if $p -> {USER} -> {Input} =~ m{^\s*$};
    warn "Couldn't parse '$p->{USER}->{Input}' at position ", pos $p->{USER}->{Input}, "\n";
}

=begin testing

# parse

=end testing

=cut

sub parse {
    my $self = shift;
    my ( $e, $expr, $action_code ) = @_;

    #warn "expr, action_code: $expr, $action_code\n";

    #warn "Parsing '$expr'\n";

    $expr =~ s{^\s*}{};
    $expr =~ s{\s*$}{};

    my $p = Gestinanna::XSM::Expression::Parser->new(
        yylex   => \&lex,
        yyerror => \&error,
        #yydebug => ($expr =~ m{gst:alzabo-schema} ? 0x1D : 0x00),
        #( $options->{Debug} || 0 ) > 5
        #    ? ( yydebug => 0x1D )
        #    : (),
    );

    #%{$p->{USER}} = %$options if $options;
    #$p->{USER}->{DEBUG} = ($expr =~ m{gst:alzabo-schema});
    $p->{USER}->{Input} = $expr;
    $p->{USER}->{e} = $e;
    #local $Data::DPath::dispatcher->{ParseNestingDepth}
    #    = $Data::DPath::dispatcher->{ParseNestingDepth} + 1;

    my $code = eval {
        $p->YYParse;                ## <== the actual parse
    };

    die $@ if $@;

#    warn "parse: $code\n";
    #warn "op tree: " . Data::Dumper -> Dump([$op_tree]);

    die map "$_\n", @{$p->{USER}->{NONONO}}
        if $p->{USER}->{NONONO} ;

    return $code;
}

1 ;
