use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::Shell::Schema;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::Shell::Schema';
        exit 0;
    }
}

plan no_plan;

my $builder = My::Builder -> current;

my %objects;

BEGIN {
use Gestinanna::PackageManager;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 13 

use Gestinanna::PackageManager;

our $package_manager = Gestinanna::PackageManager -> new( directory => 'packages' );


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}
use Gestinanna::Shell::Base;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 88 

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
use Gestinanna::SchemaManager;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 28 

use Gestinanna::SchemaManager;
our $schema_manager = Gestinanna::SchemaManager -> new();
$schema_manager -> add_packages($package_manager);

$schema_manager -> _load_runtime;
$schema_manager -> _load_create;
$Alzabo::Config::CONFIG{'root_dir'} = 'alzabo';
mkdir 'alzabo' unless -d 'alzabo';
my $schemas_dir = File::Spec -> catdir(qw(alzabo schemas));
mkdir $schemas_dir unless -d $schemas_dir;


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}
use Gestinanna::SchemaManager::Schema;
{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 4 

our $schema;
eval {
    $schema = $schema_manager -> load_schema(name => 'test');
};

if($@ || !$schema) {
    my $s = $schema_manager -> create_schema(name => 'test', rdbms => 'SQLite');
    $s -> add_schema('site');
    foreach my $prefix (qw(
        View
        XSLT
        XSM
        Document
        Portal
        WorkflowDef
    )) {
        $s -> add_schema('repository', prefix => $prefix);
    }

    $s -> add_schema('workflow', prefix => 'Workflow');

    $s -> add_schema('authorization'); # adds Authz stuff and bare user accounts

    $s -> make_live;

    $schema = $schema_manager -> load_schema(name => 'test');
}


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


}

# method: do_create

$builder -> begin_tests('do_create');


$builder -> end_tests('do_create');

# method: do_delete

$builder -> begin_tests('do_delete');


$builder -> end_tests('do_delete');

# method: do_docs

$builder -> begin_tests('do_docs');


$builder -> end_tests('do_docs');

# method: do_drop

$builder -> begin_tests('do_drop');


$builder -> end_tests('do_drop');

# method: do_help

$builder -> begin_tests('do_help');


$builder -> end_tests('do_help');

# method: do_list

$builder -> begin_tests('do_list');


$builder -> end_tests('do_list');

# method: do_load

$builder -> begin_tests('do_load');


$builder -> end_tests('do_load');

# method: do_schema

$builder -> begin_tests('do_schema');


$builder -> end_tests('do_schema');

# method: do_upgrade

$builder -> begin_tests('do_upgrade');


$builder -> end_tests('do_upgrade');
# record test results for report
$builder -> record_test_details('Gestinanna::Shell::Schema');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
