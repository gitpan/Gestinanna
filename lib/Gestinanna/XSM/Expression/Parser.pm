####################################################################
#
#    This file was generated using Parse::Yapp version 1.05.
#
#        Don't edit this file, use source file instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
####################################################################
package Gestinanna::XSM::Expression::Parser;
use vars qw ( @ISA );
use strict;

@ISA= qw ( Parse::Yapp::Driver );
#Included Parse/Yapp/Driver.pm file----------------------------------------
{
#
# Module Parse::Yapp::Driver
#
# This module is part of the Parse::Yapp package available on your
# nearest CPAN
#
# Any use of this module in a standalone parser make the included
# text under the same copyright as the Parse::Yapp module itself.
#
# This notice should remain unchanged.
#
# (c) Copyright 1998-2001 Francois Desarmenien, all rights reserved.
# (see the pod text in Parse::Yapp module for use and distribution rights)
#

package Parse::Yapp::Driver;

require 5.004;

use strict;

use vars qw ( $VERSION $COMPATIBLE $FILENAME );

$VERSION = '1.05';
$COMPATIBLE = '0.07';
$FILENAME=__FILE__;

use Carp;

#Known parameters, all starting with YY (leading YY will be discarded)
my(%params)=(YYLEX => 'CODE', 'YYERROR' => 'CODE', YYVERSION => '',
			 YYRULES => 'ARRAY', YYSTATES => 'ARRAY', YYDEBUG => '');
#Mandatory parameters
my(@params)=('LEX','RULES','STATES');

sub new {
    my($class)=shift;
	my($errst,$nberr,$token,$value,$check,$dotpos);
    my($self)={ ERROR => \&_Error,
				ERRST => \$errst,
                NBERR => \$nberr,
				TOKEN => \$token,
				VALUE => \$value,
				DOTPOS => \$dotpos,
				STACK => [],
				DEBUG => 0,
				CHECK => \$check };

	_CheckParams( [], \%params, \@_, $self );

		exists($$self{VERSION})
	and	$$self{VERSION} < $COMPATIBLE
	and	croak "Yapp driver version $VERSION ".
			  "incompatible with version $$self{VERSION}:\n".
			  "Please recompile parser module.";

        ref($class)
    and $class=ref($class);

    bless($self,$class);
}

sub YYParse {
    my($self)=shift;
    my($retval);

	_CheckParams( \@params, \%params, \@_, $self );

	if($$self{DEBUG}) {
		_DBLoad();
		$retval = eval '$self->_DBParse()';#Do not create stab entry on compile
        $@ and die $@;
	}
	else {
		$retval = $self->_Parse();
	}
    $retval
}

sub YYData {
	my($self)=shift;

		exists($$self{USER})
	or	$$self{USER}={};

	$$self{USER};
	
}

sub YYErrok {
	my($self)=shift;

	${$$self{ERRST}}=0;
    undef;
}

sub YYNberr {
	my($self)=shift;

	${$$self{NBERR}};
}

sub YYRecovering {
	my($self)=shift;

	${$$self{ERRST}} != 0;
}

sub YYAbort {
	my($self)=shift;

	${$$self{CHECK}}='ABORT';
    undef;
}

sub YYAccept {
	my($self)=shift;

	${$$self{CHECK}}='ACCEPT';
    undef;
}

sub YYError {
	my($self)=shift;

	${$$self{CHECK}}='ERROR';
    undef;
}

sub YYSemval {
	my($self)=shift;
	my($index)= $_[0] - ${$$self{DOTPOS}} - 1;

		$index < 0
	and	-$index <= @{$$self{STACK}}
	and	return $$self{STACK}[$index][1];

	undef;	#Invalid index
}

sub YYCurtok {
	my($self)=shift;

        @_
    and ${$$self{TOKEN}}=$_[0];
    ${$$self{TOKEN}};
}

sub YYCurval {
	my($self)=shift;

        @_
    and ${$$self{VALUE}}=$_[0];
    ${$$self{VALUE}};
}

sub YYExpect {
    my($self)=shift;

    keys %{$self->{STATES}[$self->{STACK}[-1][0]]{ACTIONS}}
}

sub YYLexer {
    my($self)=shift;

	$$self{LEX};
}


#################
# Private stuff #
#################


sub _CheckParams {
	my($mandatory,$checklist,$inarray,$outhash)=@_;
	my($prm,$value);
	my($prmlst)={};

	while(($prm,$value)=splice(@$inarray,0,2)) {
        $prm=uc($prm);
			exists($$checklist{$prm})
		or	croak("Unknow parameter '$prm'");
			ref($value) eq $$checklist{$prm}
		or	croak("Invalid value for parameter '$prm'");
        $prm=unpack('@2A*',$prm);
		$$outhash{$prm}=$value;
	}
	for (@$mandatory) {
			exists($$outhash{$_})
		or	croak("Missing mandatory parameter '".lc($_)."'");
	}
}

sub _Error {
	print "Parse error.\n";
}

sub _DBLoad {
	{
		no strict 'refs';

			exists(${__PACKAGE__.'::'}{_DBParse})#Already loaded ?
		and	return;
	}
	my($fname)=__FILE__;
	my(@drv);
	open(DRV,"<$fname") or die "Report this as a BUG: Cannot open $fname";
	while(<DRV>) {
                	/^\s*sub\s+_Parse\s*{\s*$/ .. /^\s*}\s*#\s*_Parse\s*$/
        	and     do {
                	s/^#DBG>//;
                	push(@drv,$_);
        	}
	}
	close(DRV);

	$drv[0]=~s/_P/_DBP/;
	eval join('',@drv);
}

#Note that for loading debugging version of the driver,
#this file will be parsed from 'sub _Parse' up to '}#_Parse' inclusive.
#So, DO NOT remove comment at end of sub !!!
sub _Parse {
    my($self)=shift;

	my($rules,$states,$lex,$error)
     = @$self{ 'RULES', 'STATES', 'LEX', 'ERROR' };
	my($errstatus,$nberror,$token,$value,$stack,$check,$dotpos)
     = @$self{ 'ERRST', 'NBERR', 'TOKEN', 'VALUE', 'STACK', 'CHECK', 'DOTPOS' };

#DBG>	my($debug)=$$self{DEBUG};
#DBG>	my($dbgerror)=0;

#DBG>	my($ShowCurToken) = sub {
#DBG>		my($tok)='>';
#DBG>		for (split('',$$token)) {
#DBG>			$tok.=		(ord($_) < 32 or ord($_) > 126)
#DBG>					?	sprintf('<%02X>',ord($_))
#DBG>					:	$_;
#DBG>		}
#DBG>		$tok.='<';
#DBG>	};

	$$errstatus=0;
	$$nberror=0;
	($$token,$$value)=(undef,undef);
	@$stack=( [ 0, undef ] );
	$$check='';

    while(1) {
        my($actions,$act,$stateno);

        $stateno=$$stack[-1][0];
        $actions=$$states[$stateno];

#DBG>	print STDERR ('-' x 40),"\n";
#DBG>		$debug & 0x2
#DBG>	and	print STDERR "In state $stateno:\n";
#DBG>		$debug & 0x08
#DBG>	and	print STDERR "Stack:[".
#DBG>					 join(',',map { $$_[0] } @$stack).
#DBG>					 "]\n";


        if  (exists($$actions{ACTIONS})) {

				defined($$token)
            or	do {
				($$token,$$value)=&$lex($self);
#DBG>				$debug & 0x01
#DBG>			and	print STDERR "Need token. Got ".&$ShowCurToken."\n";
			};

            $act=   exists($$actions{ACTIONS}{$$token})
                    ?   $$actions{ACTIONS}{$$token}
                    :   exists($$actions{DEFAULT})
                        ?   $$actions{DEFAULT}
                        :   undef;
        }
        else {
            $act=$$actions{DEFAULT};
#DBG>			$debug & 0x01
#DBG>		and	print STDERR "Don't need token.\n";
        }

            defined($act)
        and do {

                $act > 0
            and do {        #shift

#DBG>				$debug & 0x04
#DBG>			and	print STDERR "Shift and go to state $act.\n";

					$$errstatus
				and	do {
					--$$errstatus;

#DBG>					$debug & 0x10
#DBG>				and	$dbgerror
#DBG>				and	$$errstatus == 0
#DBG>				and	do {
#DBG>					print STDERR "**End of Error recovery.\n";
#DBG>					$dbgerror=0;
#DBG>				};
				};


                push(@$stack,[ $act, $$value ]);

					$$token ne ''	#Don't eat the eof
				and	$$token=$$value=undef;
                next;
            };

            #reduce
            my($lhs,$len,$code,@sempar,$semval);
            ($lhs,$len,$code)=@{$$rules[-$act]};

#DBG>			$debug & 0x04
#DBG>		and	$act
#DBG>		and	print STDERR "Reduce using rule ".-$act." ($lhs,$len): ";

                $act
            or  $self->YYAccept();

            $$dotpos=$len;

                unpack('A1',$lhs) eq '@'    #In line rule
            and do {
                    $lhs =~ /^\@[0-9]+\-([0-9]+)$/
                or  die "In line rule name '$lhs' ill formed: ".
                        "report it as a BUG.\n";
                $$dotpos = $1;
            };

            @sempar =       $$dotpos
                        ?   map { $$_[1] } @$stack[ -$$dotpos .. -1 ]
                        :   ();

            $semval = $code ? &$code( $self, @sempar )
                            : @sempar ? $sempar[0] : undef;

            splice(@$stack,-$len,$len);

                $$check eq 'ACCEPT'
            and do {

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Accept.\n";

				return($semval);
			};

                $$check eq 'ABORT'
            and	do {

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Abort.\n";

				return(undef);

			};

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Back to state $$stack[-1][0], then ";

                $$check eq 'ERROR'
            or  do {
#DBG>				$debug & 0x04
#DBG>			and	print STDERR 
#DBG>				    "go to state $$states[$$stack[-1][0]]{GOTOS}{$lhs}.\n";

#DBG>				$debug & 0x10
#DBG>			and	$dbgerror
#DBG>			and	$$errstatus == 0
#DBG>			and	do {
#DBG>				print STDERR "**End of Error recovery.\n";
#DBG>				$dbgerror=0;
#DBG>			};

			    push(@$stack,
                     [ $$states[$$stack[-1][0]]{GOTOS}{$lhs}, $semval ]);
                $$check='';
                next;
            };

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Forced Error recovery.\n";

            $$check='';

        };

        #Error
            $$errstatus
        or   do {

            $$errstatus = 1;
            &$error($self);
                $$errstatus # if 0, then YYErrok has been called
            or  next;       # so continue parsing

#DBG>			$debug & 0x10
#DBG>		and	do {
#DBG>			print STDERR "**Entering Error recovery.\n";
#DBG>			++$dbgerror;
#DBG>		};

            ++$$nberror;

        };

			$$errstatus == 3	#The next token is not valid: discard it
		and	do {
				$$token eq ''	# End of input: no hope
			and	do {
#DBG>				$debug & 0x10
#DBG>			and	print STDERR "**At eof: aborting.\n";
				return(undef);
			};

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Dicard invalid token ".&$ShowCurToken.".\n";

			$$token=$$value=undef;
		};

        $$errstatus=3;

		while(	  @$stack
			  and (		not exists($$states[$$stack[-1][0]]{ACTIONS})
			        or  not exists($$states[$$stack[-1][0]]{ACTIONS}{error})
					or	$$states[$$stack[-1][0]]{ACTIONS}{error} <= 0)) {

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Pop state $$stack[-1][0].\n";

			pop(@$stack);
		}

			@$stack
		or	do {

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**No state left on stack: aborting.\n";

			return(undef);
		};

		#shift the error token

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Shift \$error token and go to state ".
#DBG>						 $$states[$$stack[-1][0]]{ACTIONS}{error}.
#DBG>						 ".\n";

		push(@$stack, [ $$states[$$stack[-1][0]]{ACTIONS}{error}, undef ]);

    }

    #never reached
	croak("Error in driver logic. Please, report it as a BUG");

}#_Parse
#DO NOT remove comment

1;

}
#End of include--------------------------------------------------


#line 10 "unkown"

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


sub new {
        my($class)=shift;
        ref($class)
    and $class=ref($class);

    my($self)=$class->SUPER::new( yyversion => '1.05',
                                  yystates =>
[
	{#State 0
		ACTIONS => {
			'DOT_DOT' => 20,
			'SLASH_SLASH' => 23,
			'MINUS' => 22,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'range_expr' => 8,
			'expr' => 26,
			'location_path' => 9,
			'and_expr' => 12,
			'or_expr' => 14,
			'additive_expr' => 16,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 1
		DEFAULT => -39
	},
	{#State 2
		ACTIONS => {
			'BANG_EQUALS' => 35,
			'EQUALS_EQUALS' => 34,
			'EQUALS' => 33
		},
		DEFAULT => -6
	},
	{#State 3
		DEFAULT => -56
	},
	{#State 4
		ACTIONS => {
			'VBAR' => 36
		},
		DEFAULT => -29
	},
	{#State 5
		ACTIONS => {
			'QNAME' => 40,
			'LCRL' => 41,
			'STAR' => 37,
			'NUMBER' => 39
		},
		GOTOS => {
			'node_test' => 38
		}
	},
	{#State 6
		ACTIONS => {
			'AT' => 3,
			'DOT' => 11,
			'AXIS_METHOD' => 15,
			'STAR' => -54,
			'AXIS_NAME' => 42,
			'DOT_DOT' => 20,
			'NUMBER' => -54,
			'QNAME' => -54,
			'LCRL' => -54
		},
		DEFAULT => -40,
		GOTOS => {
			'step' => 7,
			'relative_location_path' => 43,
			'axis' => 5
		}
	},
	{#State 7
		DEFAULT => -45
	},
	{#State 8
		DEFAULT => -2
	},
	{#State 9
		DEFAULT => -33
	},
	{#State 10
		ACTIONS => {
			'LPAR' => 44
		}
	},
	{#State 11
		DEFAULT => -52
	},
	{#State 12
		ACTIONS => {
			'AMP_AMP' => 45,
			'AMP' => 46,
			'AND' => 47
		},
		DEFAULT => -3
	},
	{#State 13
		DEFAULT => -59
	},
	{#State 14
		ACTIONS => {
			'VBAR_VBAR' => 49,
			'OR' => 48
		},
		DEFAULT => -1
	},
	{#State 15
		ACTIONS => {
			'COLON_COLON' => 50
		}
	},
	{#State 16
		ACTIONS => {
			'MINUS' => 52,
			'PLUS' => 51,
			'RANGE' => 53
		},
		DEFAULT => -14
	},
	{#State 17
		DEFAULT => -23
	},
	{#State 18
		ACTIONS => {
			'COLON_COLON' => 54
		}
	},
	{#State 19
		ACTIONS => {
			'LTE' => 55,
			'LT' => 58,
			'GTE' => 56,
			'GT' => 57
		},
		DEFAULT => -10
	},
	{#State 20
		DEFAULT => -53
	},
	{#State 21
		ACTIONS => {
			'VBAR' => 59
		},
		DEFAULT => -30
	},
	{#State 22
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'location_path' => 9,
			'unary_expr' => 60,
			'primary_expr' => 30,
			'union_expr' => 31
		}
	},
	{#State 23
		ACTIONS => {
			'DOT_DOT' => 20,
			'DOT' => 11,
			'AT' => 3,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 42
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 7,
			'relative_location_path' => 61,
			'axis' => 5
		}
	},
	{#State 24
		ACTIONS => {
			'SLASH_SLASH' => 63,
			'SLASH' => 62
		},
		DEFAULT => -38
	},
	{#State 25
		DEFAULT => -62
	},
	{#State 26
		ACTIONS => {
			'' => 64
		}
	},
	{#State 27
		DEFAULT => -63
	},
	{#State 28
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'range_expr' => 8,
			'expr' => 65,
			'location_path' => 9,
			'and_expr' => 12,
			'or_expr' => 14,
			'additive_expr' => 16,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 29
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'range_expr' => 8,
			'expr' => 66,
			'location_path' => 9,
			'and_expr' => 12,
			'or_expr' => 14,
			'additive_expr' => 16,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 30
		DEFAULT => -57,
		GOTOS => {
			'predicates' => 67
		}
	},
	{#State 31
		DEFAULT => -27
	},
	{#State 32
		ACTIONS => {
			'MULTIPLY' => 68,
			'DIV' => 69,
			'MOD' => 70
		},
		DEFAULT => -20
	},
	{#State 33
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 71,
			'primary_expr' => 30,
			'location_path' => 9,
			'unary_expr' => 17,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 72
		}
	},
	{#State 34
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 71,
			'primary_expr' => 30,
			'location_path' => 9,
			'unary_expr' => 17,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 73
		}
	},
	{#State 35
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 71,
			'primary_expr' => 30,
			'location_path' => 9,
			'unary_expr' => 17,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 74
		}
	},
	{#State 36
		ACTIONS => {
			'DOT_DOT' => 20,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 7,
			'absolute_location_path' => 1,
			'primary_expr' => 30,
			'relative_location_path' => 24,
			'location_path' => 9,
			'path_expr' => 75,
			'axis' => 5
		}
	},
	{#State 37
		DEFAULT => -71
	},
	{#State 38
		DEFAULT => -57,
		GOTOS => {
			'predicates' => 76
		}
	},
	{#State 39
		DEFAULT => -70
	},
	{#State 40
		DEFAULT => -69
	},
	{#State 41
		ACTIONS => {
			'DOLLAR_QNAME' => 77
		}
	},
	{#State 42
		ACTIONS => {
			'COLON_COLON' => 78
		}
	},
	{#State 43
		ACTIONS => {
			'SLASH_SLASH' => 63,
			'SLASH' => 62
		},
		DEFAULT => -41
	},
	{#State 44
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18,
			'RPAR' => -65
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'args' => 79,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'range_expr' => 8,
			'expr' => 80,
			'location_path' => 9,
			'and_expr' => 12,
			'or_expr' => 14,
			'opt_args' => 81,
			'additive_expr' => 16,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 45
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 82,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 71,
			'primary_expr' => 30,
			'location_path' => 9,
			'unary_expr' => 17,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 46
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 83,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 71,
			'primary_expr' => 30,
			'location_path' => 9,
			'unary_expr' => 17,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 47
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 84,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 71,
			'primary_expr' => 30,
			'location_path' => 9,
			'unary_expr' => 17,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 48
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'and_expr' => 85,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 71,
			'primary_expr' => 30,
			'location_path' => 9,
			'unary_expr' => 17,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 49
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'and_expr' => 86,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 71,
			'primary_expr' => 30,
			'location_path' => 9,
			'unary_expr' => 17,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 50
		ACTIONS => {
			'FUNCTION_NAME' => 87,
			'QNAME' => 40,
			'STAR' => 37,
			'NUMBER' => 39
		},
		GOTOS => {
			'node_test' => 88
		}
	},
	{#State 51
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'location_path' => 9,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 89
		}
	},
	{#State 52
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'location_path' => 9,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 90
		}
	},
	{#State 53
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 91,
			'location_path' => 9,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32
		}
	},
	{#State 54
		ACTIONS => {
			'SLASH_SLASH' => 93,
			'SLASH' => 92
		},
		DEFAULT => -55
	},
	{#State 55
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 94,
			'location_path' => 9,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32
		}
	},
	{#State 56
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 95,
			'location_path' => 9,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32
		}
	},
	{#State 57
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 96,
			'location_path' => 9,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32
		}
	},
	{#State 58
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'additive_expr' => 97,
			'location_path' => 9,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32
		}
	},
	{#State 59
		ACTIONS => {
			'DOT_DOT' => 20,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 7,
			'absolute_location_path' => 1,
			'primary_expr' => 30,
			'relative_location_path' => 24,
			'location_path' => 9,
			'path_expr' => 98,
			'axis' => 5
		}
	},
	{#State 60
		DEFAULT => -28
	},
	{#State 61
		ACTIONS => {
			'SLASH_SLASH' => 63,
			'SLASH' => 62
		},
		DEFAULT => -42
	},
	{#State 62
		ACTIONS => {
			'DOT_DOT' => 20,
			'DOT' => 11,
			'AT' => 3,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 42
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 99,
			'axis' => 5
		}
	},
	{#State 63
		ACTIONS => {
			'DOT_DOT' => 20,
			'DOT' => 11,
			'AT' => 3,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 42
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 100,
			'axis' => 5
		}
	},
	{#State 64
		DEFAULT => 0
	},
	{#State 65
		ACTIONS => {
			'GT' => 101
		}
	},
	{#State 66
		ACTIONS => {
			'RPAR' => 102
		}
	},
	{#State 67
		ACTIONS => {
			'SLASH_SLASH' => 105,
			'SLASH' => 104,
			'LSQB' => 106
		},
		DEFAULT => -35,
		GOTOS => {
			'segment' => 103
		}
	},
	{#State 68
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'location_path' => 9,
			'unary_expr' => 107,
			'primary_expr' => 30,
			'union_expr' => 31
		}
	},
	{#State 69
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'location_path' => 9,
			'unary_expr' => 108,
			'primary_expr' => 30,
			'union_expr' => 31
		}
	},
	{#State 70
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'location_path' => 9,
			'unary_expr' => 109,
			'primary_expr' => 30,
			'union_expr' => 31
		}
	},
	{#State 71
		ACTIONS => {
			'MINUS' => 52,
			'PLUS' => 51
		},
		DEFAULT => -14
	},
	{#State 72
		ACTIONS => {
			'LTE' => 55,
			'LT' => 58,
			'GTE' => 56,
			'GT' => 57
		},
		DEFAULT => -11
	},
	{#State 73
		ACTIONS => {
			'LTE' => 55,
			'LT' => 58,
			'GTE' => 56,
			'GT' => 57
		},
		DEFAULT => -13
	},
	{#State 74
		ACTIONS => {
			'LTE' => 55,
			'LT' => 58,
			'GTE' => 56,
			'GT' => 57
		},
		DEFAULT => -12
	},
	{#State 75
		DEFAULT => -31
	},
	{#State 76
		ACTIONS => {
			'LSQB' => 106
		},
		DEFAULT => -48
	},
	{#State 77
		ACTIONS => {
			'RCRL' => 110
		}
	},
	{#State 78
		DEFAULT => -55
	},
	{#State 79
		ACTIONS => {
			'COMMA' => 111
		},
		DEFAULT => -66
	},
	{#State 80
		DEFAULT => -67
	},
	{#State 81
		ACTIONS => {
			'RPAR' => 112
		}
	},
	{#State 82
		ACTIONS => {
			'BANG_EQUALS' => 35,
			'EQUALS_EQUALS' => 34,
			'EQUALS' => 33
		},
		DEFAULT => -8
	},
	{#State 83
		ACTIONS => {
			'BANG_EQUALS' => 35,
			'EQUALS_EQUALS' => 34,
			'EQUALS' => 33
		},
		DEFAULT => -9
	},
	{#State 84
		ACTIONS => {
			'BANG_EQUALS' => 35,
			'EQUALS_EQUALS' => 34,
			'EQUALS' => 33
		},
		DEFAULT => -7
	},
	{#State 85
		ACTIONS => {
			'AMP_AMP' => 45,
			'AMP' => 46,
			'AND' => 47
		},
		DEFAULT => -4
	},
	{#State 86
		ACTIONS => {
			'AMP_AMP' => 45,
			'AMP' => 46,
			'AND' => 47
		},
		DEFAULT => -5
	},
	{#State 87
		ACTIONS => {
			'LPAR' => 113
		}
	},
	{#State 88
		DEFAULT => -57,
		GOTOS => {
			'predicates' => 114
		}
	},
	{#State 89
		ACTIONS => {
			'MULTIPLY' => 68,
			'DIV' => 69,
			'MOD' => 70
		},
		DEFAULT => -21
	},
	{#State 90
		ACTIONS => {
			'MULTIPLY' => 68,
			'DIV' => 69,
			'MOD' => 70
		},
		DEFAULT => -22
	},
	{#State 91
		ACTIONS => {
			'MINUS' => 52,
			'PLUS' => 51
		},
		DEFAULT => -19
	},
	{#State 92
		ACTIONS => {
			'DOT_DOT' => 20,
			'DOT' => 11,
			'AT' => 3,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 42
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 7,
			'relative_location_path' => 115,
			'axis' => 5
		}
	},
	{#State 93
		ACTIONS => {
			'DOT_DOT' => 20,
			'DOT' => 11,
			'AT' => 3,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 42
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 7,
			'relative_location_path' => 116,
			'axis' => 5
		}
	},
	{#State 94
		ACTIONS => {
			'MINUS' => 52,
			'PLUS' => 51
		},
		DEFAULT => -17
	},
	{#State 95
		ACTIONS => {
			'MINUS' => 52,
			'PLUS' => 51
		},
		DEFAULT => -18
	},
	{#State 96
		ACTIONS => {
			'MINUS' => 52,
			'PLUS' => 51
		},
		DEFAULT => -16
	},
	{#State 97
		ACTIONS => {
			'MINUS' => 52,
			'PLUS' => 51
		},
		DEFAULT => -15
	},
	{#State 98
		DEFAULT => -32
	},
	{#State 99
		DEFAULT => -46
	},
	{#State 100
		DEFAULT => -47
	},
	{#State 101
		DEFAULT => -60
	},
	{#State 102
		DEFAULT => -61
	},
	{#State 103
		DEFAULT => -34
	},
	{#State 104
		ACTIONS => {
			'DOT_DOT' => 20,
			'DOT' => 11,
			'AT' => 3,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 42
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 7,
			'relative_location_path' => 117,
			'axis' => 5
		}
	},
	{#State 105
		ACTIONS => {
			'DOT_DOT' => 20,
			'DOT' => 11,
			'AT' => 3,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 42
		},
		DEFAULT => -54,
		GOTOS => {
			'step' => 7,
			'relative_location_path' => 118,
			'axis' => 5
		}
	},
	{#State 106
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'range_expr' => 8,
			'expr' => 119,
			'location_path' => 9,
			'and_expr' => 12,
			'or_expr' => 14,
			'additive_expr' => 16,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 107
		DEFAULT => -24
	},
	{#State 108
		DEFAULT => -25
	},
	{#State 109
		DEFAULT => -26
	},
	{#State 110
		DEFAULT => -57,
		GOTOS => {
			'predicates' => 120
		}
	},
	{#State 111
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'range_expr' => 8,
			'expr' => 121,
			'location_path' => 9,
			'and_expr' => 12,
			'or_expr' => 14,
			'additive_expr' => 16,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 112
		DEFAULT => -64
	},
	{#State 113
		ACTIONS => {
			'DOT_DOT' => 20,
			'MINUS' => 22,
			'SLASH_SLASH' => 23,
			'AT' => 3,
			'LITERAL' => 25,
			'SLASH' => 6,
			'NUMBER' => 27,
			'FUNCTION_NAME' => 10,
			'DOT' => 11,
			'DOLLAR_QNAME' => 13,
			'LT' => 28,
			'LPAR' => 29,
			'AXIS_METHOD' => 15,
			'AXIS_NAME' => 18,
			'RPAR' => -65
		},
		DEFAULT => -54,
		GOTOS => {
			'union_expr_x' => 21,
			'absolute_location_path' => 1,
			'relative_location_path' => 24,
			'equality_expr' => 2,
			'args' => 79,
			'path_expr' => 4,
			'axis' => 5,
			'step' => 7,
			'range_expr' => 8,
			'expr' => 80,
			'location_path' => 9,
			'and_expr' => 12,
			'or_expr' => 14,
			'opt_args' => 122,
			'additive_expr' => 16,
			'unary_expr' => 17,
			'primary_expr' => 30,
			'union_expr' => 31,
			'multiplicative_expr' => 32,
			'relational_expr' => 19
		}
	},
	{#State 114
		ACTIONS => {
			'LSQB' => 106
		},
		DEFAULT => -50
	},
	{#State 115
		ACTIONS => {
			'SLASH_SLASH' => 63,
			'SLASH' => 62
		},
		DEFAULT => -43
	},
	{#State 116
		ACTIONS => {
			'SLASH_SLASH' => 63,
			'SLASH' => 62
		},
		DEFAULT => -44
	},
	{#State 117
		ACTIONS => {
			'SLASH_SLASH' => 63,
			'SLASH' => 62
		},
		DEFAULT => -36
	},
	{#State 118
		ACTIONS => {
			'SLASH_SLASH' => 63,
			'SLASH' => 62
		},
		DEFAULT => -37
	},
	{#State 119
		ACTIONS => {
			'RSQB' => 123
		}
	},
	{#State 120
		ACTIONS => {
			'LSQB' => 106
		},
		DEFAULT => -49
	},
	{#State 121
		DEFAULT => -68
	},
	{#State 122
		ACTIONS => {
			'RPAR' => 124
		}
	},
	{#State 123
		DEFAULT => -58
	},
	{#State 124
		DEFAULT => -57,
		GOTOS => {
			'predicates' => 125
		}
	},
	{#State 125
		ACTIONS => {
			'LSQB' => 106
		},
		DEFAULT => -51
	}
],
                                  yyrules  =>
[
	[#Rule 0
		 '$start', 2, undef
	],
	[#Rule 1
		 'expr', 1, undef
	],
	[#Rule 2
		 'expr', 1, undef
	],
	[#Rule 3
		 'or_expr', 1, undef
	],
	[#Rule 4
		 'or_expr', 3,
sub
#line 103 "unkown"
{ '(' . $_[1] . ') || (' . $_[3] . ')' }
	],
	[#Rule 5
		 'or_expr', 3,
sub
#line 104 "unkown"
{
        die "DPath uses 'or' instead of Perl's '||'\n";
    }
	],
	[#Rule 6
		 'and_expr', 1, undef
	],
	[#Rule 7
		 'and_expr', 3,
sub
#line 111 "unkown"
{ '(' . $_[1] . ') && (' . $_[3] . ')' }
	],
	[#Rule 8
		 'and_expr', 3,
sub
#line 112 "unkown"
{
        die "DPath uses 'and' instead of Perl's '&&'\n";
    }
	],
	[#Rule 9
		 'and_expr', 3,
sub
#line 115 "unkown"
{
        die "DPath uses 'and' instead of Perl's '&'\n";
    }
	],
	[#Rule 10
		 'equality_expr', 1, undef
	],
	[#Rule 11
		 'equality_expr', 3,
sub
#line 122 "unkown"
{ '(0 == Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
	],
	[#Rule 12
		 'equality_expr', 3,
sub
#line 123 "unkown"
{ '(0 != Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
	],
	[#Rule 13
		 'equality_expr', 3,
sub
#line 124 "unkown"
{ 
        die "XSM expressions use '=' instead of Perl's '=='\n";
    }
	],
	[#Rule 14
		 'relational_expr', 1, undef
	],
	[#Rule 15
		 'relational_expr', 3,
sub
#line 131 "unkown"
{ '(0 > Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
	],
	[#Rule 16
		 'relational_expr', 3,
sub
#line 132 "unkown"
{ '(0 < Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
	],
	[#Rule 17
		 'relational_expr', 3,
sub
#line 133 "unkown"
{ '(0 >= Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
	],
	[#Rule 18
		 'relational_expr', 3,
sub
#line 134 "unkown"
{ '(0 <= Gestinanna::XSM::Expression::xsm_cmp([' . $_[1] . '], [' . $_[3] . ']))' }
	],
	[#Rule 19
		 'range_expr', 3,
sub
#line 138 "unkown"
{ "Gestinanna::XSM::Expression::xsm_range(($_[1])[0], ($_[3])[0])" }
	],
	[#Rule 20
		 'additive_expr', 1, undef
	],
	[#Rule 21
		 'additive_expr', 3,
sub
#line 143 "unkown"
{ '(' . $_[1] . ') + (' . $_[3] . ')' }
	],
	[#Rule 22
		 'additive_expr', 3,
sub
#line 144 "unkown"
{ '(' . $_[1] . ') - (' . $_[3] . ')' }
	],
	[#Rule 23
		 'multiplicative_expr', 1, undef
	],
	[#Rule 24
		 'multiplicative_expr', 3,
sub
#line 149 "unkown"
{ '(' . $_[1] . ') * (' . $_[3] . ')' }
	],
	[#Rule 25
		 'multiplicative_expr', 3,
sub
#line 150 "unkown"
{ '(' . $_[1] . ') / (' . $_[3] . ')' }
	],
	[#Rule 26
		 'multiplicative_expr', 3,
sub
#line 151 "unkown"
{ '(' . $_[1] . ') % (' . $_[3] . ')' }
	],
	[#Rule 27
		 'unary_expr', 1, undef
	],
	[#Rule 28
		 'unary_expr', 2,
sub
#line 156 "unkown"
{ '-(' . $_[2] . ')'  }
	],
	[#Rule 29
		 'union_expr', 1, undef
	],
	[#Rule 30
		 'union_expr', 1,
sub
#line 161 "unkown"
{ '[ ' . $_[1] . ' ]' }
	],
	[#Rule 31
		 'union_expr_x', 3,
sub
#line 165 "unkown"
{ "($_[1]),($_[3])" }
	],
	[#Rule 32
		 'union_expr_x', 3,
sub
#line 166 "unkown"
{ "$_[1],($_[3])" }
	],
	[#Rule 33
		 'path_expr', 1, undef
	],
	[#Rule 34
		 'path_expr', 3,
sub
#line 171 "unkown"
{ no warnings; $_[3] . ' ' . $_[2] . ' (' . $_[1] . ')'; }
	],
	[#Rule 35
		 'segment', 0, undef
	],
	[#Rule 36
		 'segment', 2,
sub
#line 176 "unkown"
{ $_[2] }
	],
	[#Rule 37
		 'segment', 2,
sub
#line 177 "unkown"
{ "grep { defined } map { map { $_[2] } Gestinanna::XSM::Expression::axis_descendent_or_self(\$_, '*') } " }
	],
	[#Rule 38
		 'location_path', 1,
sub
#line 181 "unkown"
{ ($_[1] =~ m{\$topic$}) ? $_[1] : $_[1] . ' $topic ' }
	],
	[#Rule 39
		 'location_path', 1, undef
	],
	[#Rule 40
		 'absolute_location_path', 1,
sub
#line 186 "unkown"
{ '$data{"local"}' }
	],
	[#Rule 41
		 'absolute_location_path', 2,
sub
#line 187 "unkown"
{ $_[2] . ' $data{"local"}' }
	],
	[#Rule 42
		 'absolute_location_path', 2,
sub
#line 188 "unkown"
{ $_[2] . ' Gestinanna::XSM::Expression::axis_descendent_or_self($data{"local"},"*")' }
	],
	[#Rule 43
		 'absolute_location_path', 4,
sub
#line 189 "unkown"
{ $_[4] . " \$data{\"\Q$_[1]\E\"}" }
	],
	[#Rule 44
		 'absolute_location_path', 4,
sub
#line 190 "unkown"
{ $_[4] . "Gestinanna::XSM::Expression::axis_descendent_or_self(\$data{\"\Q$_[1]\E\"},'*')" }
	],
	[#Rule 45
		 'relative_location_path', 1, undef
	],
	[#Rule 46
		 'relative_location_path', 3,
sub
#line 195 "unkown"
{ $_[3] . ' ' . $_[1] }
	],
	[#Rule 47
		 'relative_location_path', 3,
sub
#line 199 "unkown"
{ $_[3] . ' grep { defined } map { Gestinanna::XSM::Expression::axis_descendent_or_self($_, "*") } ' . $_[1] }
	],
	[#Rule 48
		 'step', 3,
sub
#line 203 "unkown"
{ 
        my($axis, $node_test, $predicates) = @_[1..$#_];
        return "" unless defined $node_test;  # is this correct?
        $axis = "child" unless defined $axis;
        $axis =~ tr/-/_/;
        $predicates = "" unless defined $predicates;
        return qq{$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_$axis(\$_, "\Q$node_test\E") }};
    }
	],
	[#Rule 49
		 'step', 5,
sub
#line 211 "unkown"
{
        my($axis, $dqname, $predicates) = @_[1,3,5..$#_];
        return "" unless defined $dqname;  # is this correct?   
        $axis = "child" unless defined $axis;
        $axis =~ tr/-/_/;
        $predicates = "" unless defined $predicates;
        return qq{$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_$axis(\$_, \$vars{"\Q$dqname\E"}) }};
    }
	],
	[#Rule 50
		 'step', 4,
sub
#line 219 "unkown"
{
        my($node_test, $predicates) = @_[3,4];
        return "" unless defined $node_test;  # is this correct?
        $predicates = "" unless defined $predicates;
        return qq{$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_method(\$_, "\Q$node_test\E") }};
    }
	],
	[#Rule 51
		 'step', 7,
sub
#line 225 "unkown"
{
        my($node_test, $args, $predicates) = @_[3, 5, 7];
        return "" unless defined $node_test;  # is this correct?
        $predicates = "" unless defined $predicates;
        return qq[$predicates grep { defined } map { Gestinanna::XSM::Expression::axis_method(\$_, "\Q$node_test\E", (] 
               . join("),(", @{$args||[]}) . ')) }';
    }
	],
	[#Rule 52
		 'step', 1,
sub
#line 232 "unkown"
{ '$topic' }
	],
	[#Rule 53
		 'step', 1,
sub
#line 233 "unkown"
{ _no @_; }
	],
	[#Rule 54
		 'axis', 0,
sub
#line 245 "unkown"
{ }
	],
	[#Rule 55
		 'axis', 2,
sub
#line 246 "unkown"
{ $_[1] }
	],
	[#Rule 56
		 'axis', 1,
sub
#line 247 "unkown"
{ 'attribute'}
	],
	[#Rule 57
		 'predicates', 0,
sub
#line 251 "unkown"
{ }
	],
	[#Rule 58
		 'predicates', 4,
sub
#line 252 "unkown"
{ 
        no warnings;
        'grep { local($topic) = $_; ' . $_[3] . ' } ' . $_[1] 
    }
	],
	[#Rule 59
		 'primary_expr', 1,
sub
#line 259 "unkown"
{ "\$vars{\"\Q$_[1]\E\"}" }
	],
	[#Rule 60
		 'primary_expr', 3,
sub
#line 260 "unkown"
{ # expr is expected to be a statement that needs to be called until it returns undef or nothing
       qq{do { my(\@list, \$t, \@t);  push \@list, \$t, \@t while( ((\$t, \@t) = ($_[2])) && defined \$t); \@list; }}
    }
	],
	[#Rule 61
		 'primary_expr', 3,
sub
#line 263 "unkown"
{ '(' . $_[2] . ')' }
	],
	[#Rule 62
		 'primary_expr', 1,
sub
#line 264 "unkown"
{ "\"\Q$_[1]\E\"" }
	],
	[#Rule 63
		 'primary_expr', 1, undef
	],
	[#Rule 64
		 'primary_expr', 4,
sub
#line 266 "unkown"
{ 
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
	],
	[#Rule 65
		 'opt_args', 0,
sub
#line 336 "unkown"
{ [] }
	],
	[#Rule 66
		 'opt_args', 1, undef
	],
	[#Rule 67
		 'args', 1,
sub
#line 341 "unkown"
{ [ $_[1] ] }
	],
	[#Rule 68
		 'args', 3,
sub
#line 342 "unkown"
{ 
        push @{$_[1]}, $_[3];
        $_[1];
    }
	],
	[#Rule 69
		 'node_test', 1,
sub
#line 349 "unkown"
{ $_[1] }
	],
	[#Rule 70
		 'node_test', 1, undef
	],
	[#Rule 71
		 'node_test', 1,
sub
#line 351 "unkown"
{ '*' }
	]
],
                                  @_);
    bless($self,$class);
}

#line 354 "unkown"

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

1;
