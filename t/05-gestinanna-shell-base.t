use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::Shell::Base;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::Shell::Base';
        exit 0;
    }
}

plan no_plan;

my $builder = My::Builder -> current;

my %objects;

BEGIN {
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 4 

use Expect;

our $exp = Expect -> new;
$exp -> spawn("perl",
                  "-Iblib/lib",
                  "-It/lib",
                  "-MGestinanna",
                  "-e",
                  "shell",
                  "--",
                  "-p",
                  "-f t/gstrc")
        or die "Cannot spawn: $!\n";
$exp -> stty(qw(echo));
$exp -> log_stdout(1);

sub shell_command_ok {
    my($command) = shift;

    return if $command =~ m{^\s*#}
           || $command =~ m{^\s*$};

    $exp -> expect(20, -re => 'gst>')
        or die "Unable to find prompt\n";
    print $exp "$command\r";
    eval {
        $exp -> expect(20,
            [
             qr'NOT OK:',
             sub {
                 die "Command ($command) did not complete successfully";
             },
            ],
            [
             qr'Unknown command',
             sub {
                 die "Unknown command - error in test script";
             },  
            ],
            [
             qr'OK',
             sub {
                 die "Command completed successfully";
             },
            ],
        ) or die "Unable to find OK\n";
    };
    my $e = $@;
    if($e !~ m{Command completed successfully}) {
        ok(0, $command);
        main::diag($e);
    }
    else {
        ok(1, $command);
    }
    my @bits = split(/[\n\r]+/, $exp -> before());
    shift @bits;
    my $out = join("\n", @bits);
    chomp($out);
    return $out;
}
    
END { 
    our $exp;
    if($exp) {
        print $exp "quit\r";
        eval {
            $exp -> do_soft_close;
            undef $exp;
        };
    }
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

}

# method: alzabo_params

$builder -> begin_tests('alzabo_params');


$builder -> end_tests('alzabo_params');

# method: do_bug

$builder -> begin_tests('do_bug');


$builder -> end_tests('do_bug');

# method: do_cd

$builder -> begin_tests('do_cd');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 348 

shell_command_ok("cd t");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_cd');

# method: do_help

$builder -> begin_tests('do_help');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 300 

my $t = shell_command_ok("?");

ok($t =~ m{The following commands are available:});
ok($t =~ m{\bbug\b});
ok($t =~ m{\bset\b});
ok($t =~ m{\bquit\b});
ok($t =~ m{\bcd\b});
ok($t =~ m{\bpwd\b});


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_help');

# method: do_pwd

$builder -> begin_tests('do_pwd');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 364 

my $pwd = shell_command_ok("pwd");

my @bits = File::Spec -> splitdir($pwd);
ok($bits[$#bits] eq 't');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_pwd');

# method: do_quit

$builder -> begin_tests('do_quit');


$builder -> end_tests('do_quit');

# method: do_readfile

$builder -> begin_tests('do_readfile');


$builder -> end_tests('do_readfile');

# method: do_set

$builder -> begin_tests('do_set');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 481 

Gestinanna::Shell::Base::do_set({ }, '', q{password 1234abcd});
is($Gestinanna::Shell::password, "1234abcd");
is($Gestinanna::Shell::VARIABLES{'password'}, 'set');

Gestinanna::Shell::Base::do_set({ }, '', q{password});
is($Gestinanna::Shell::password, '');
is($Gestinanna::Shell::VARIABLES{'password'}, 'unset');

Gestinanna::Shell::Base::do_set({ }, '', q{foo bar});
is($Gestinanna::Shell::VARIABLES{'foo'}, 'bar');

shell_command_ok("set foo bar");

my $t;

shell_command_ok("set password 1234abcd");
$t = shell_command_ok("set");
ok($t =~ m{^password\s+\[set\]$}m);

shell_command_ok("set password");
$t = shell_command_ok("set");
ok($t =~ m{^password\s+\[unset\]$}m);

shell_command_ok('set bar $(foo)');
$t = shell_command_ok("set");
ok($t =~ m{^bar\s+\[bar\]$}m);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_set');

# method: edit

$builder -> begin_tests('edit');


$builder -> end_tests('edit');

# method: edit_xml

$builder -> begin_tests('edit_xml');


$builder -> end_tests('edit_xml');

# method: init_commands

$builder -> begin_tests('init_commands');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 181 

my $cmds = { };
Gestinanna::Shell::Base -> init_commands($cmds);

ok(eq_set([ keys %$cmds ], [qw(
    bug
    set
    quit
    ?
    cd
    pwd
    .
)]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('init_commands');

# method: interpret

$builder -> begin_tests('interpret');


$builder -> end_tests('interpret');

# method: page

$builder -> begin_tests('page');


$builder -> end_tests('page');
# record test results for report
$builder -> record_test_details('Gestinanna::Shell::Base');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
