use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::Shell::Package;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::Shell::Package';
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

# method: do_activate

$builder -> begin_tests('do_activate');


$builder -> end_tests('do_activate');

# method: do_add_tagged

$builder -> begin_tests('do_add_tagged');


$builder -> end_tests('do_add_tagged');

# method: do_clear

$builder -> begin_tests('do_clear');


$builder -> end_tests('do_clear');

# method: do_close

$builder -> begin_tests('do_close');


$builder -> end_tests('do_close');

# method: do_create

$builder -> begin_tests('do_create');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 239 

# tests the full package creation through to write and then deletes the package

shell_command_ok("package create application gst_testing 0.$$");

my $pkg = shell_command_ok("package");

my @bits = split(/\s+/, $pkg);
is($bits[2], 'application');
is($bits[3], 'gst_testing');
is($bits[4], "0.$$");

my $manifest = shell_command_ok("package view MANIFEST");

my $list = shell_command_ok("package list");

ok(eq_set([ split(/\n/, $manifest) ], [ split(/\n/, $list) ]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_create');

# method: do_deactivate

$builder -> begin_tests('do_deactivate');


$builder -> end_tests('do_deactivate');

# method: do_delete

$builder -> begin_tests('do_delete');


$builder -> end_tests('do_delete');

# method: do_edit

$builder -> begin_tests('do_edit');


$builder -> end_tests('do_edit');

# method: do_get

$builder -> begin_tests('do_get');


$builder -> end_tests('do_get');

# method: do_help

$builder -> begin_tests('do_help');


$builder -> end_tests('do_help');

# method: do_install

$builder -> begin_tests('do_install');


$builder -> end_tests('do_install');

# method: do_list_packages

$builder -> begin_tests('do_list_packages');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 129 

shell_command_ok("set package_dir packages");
my $list = shell_command_ok("packages");

my @bits = split(/\n/, $list);
my %packages;
my $type;
while(@bits) {
    my $bit = shift @bits;
    if($bit =~ s{^\s+}{}) {
        next unless defined $type;
        my($pkg, $v) = split(/\s+/, $bit, 2);
        $packages{$type}{$pkg} = $v;
    }
    else {
        next unless defined $bit && length($bit) > 2;
        $type = substr($bit, 0, length($bit)-1);
    }
}

is($packages{'application'}{'base'}, '0.04');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_list_packages');

# method: do_load

$builder -> begin_tests('do_load');


$builder -> end_tests('do_load');

# method: do_open

$builder -> begin_tests('do_open');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 317 

shell_command_ok("package open application base");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_open');

# method: do_package

$builder -> begin_tests('do_package');


$builder -> end_tests('do_package');

# method: do_recommend

$builder -> begin_tests('do_recommend');


$builder -> end_tests('do_recommend');

# method: do_set

$builder -> begin_tests('do_set');


$builder -> end_tests('do_set');

# method: do_store

$builder -> begin_tests('do_store');


$builder -> end_tests('do_store');

# method: do_submit

$builder -> begin_tests('do_submit');


$builder -> end_tests('do_submit');

# method: do_update

$builder -> begin_tests('do_update');


$builder -> end_tests('do_update');

# method: do_write

$builder -> begin_tests('do_write');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 536 

shell_command_ok("package create application gst_testing 0.$$");

shell_command_ok("package write"); 

my $filename = File::Spec -> catfile(qw(packages application), "gst_testing-0.$$.tgz");
      
ok(-e $filename && -f _ && -r _, "Tarball created and readable: $filename");

shell_command_ok("package open application gst_testing");
            
$pkg = shell_command_ok("package");
          
@bits = split(/\s+/, $pkg);
is($bits[2], 'application');
is($bits[3], 'gst_testing');
is($bits[4], "0.$$");
    
unlink $filename;


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_write');

# method: do_list

$builder -> begin_tests('do_list');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 375 

my $list = shell_command_ok("package list");

our %files = map { $_ => 1 } split(/\n/, $list);

ok($files{'conf/package.conf'}, "conf/package.conf exists");
ok($files{'MANIFEST'}, "MANIFEST exists");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_list');

# method: do_view

$builder -> begin_tests('do_view');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 495 

my $manifest = shell_command_ok("package view MANIFEST");

ok(eq_set([ keys %files ], [ split(/\n/, $manifest) ]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('do_view');
# record test results for report
$builder -> record_test_details('Gestinanna::Shell::Package');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
