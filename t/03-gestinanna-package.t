use lib q{t/lib};
use My::Builder;
# Testing found 1 nodes
use Test::More;
use Module::Build;

BEGIN {
    eval {
        require Gestinanna::Package;
    };

    if($@) {
        plan skip_all => 'Unable to load Gestinanna::Package';
        exit 0;
    }
}

plan no_plan;

my $builder = My::Builder -> current;

my %objects;

$builder -> begin_tests('new');
eval {
    $objects{'_default'} = Gestinanna::Package -> new();
};
ok(!$@);
isa_ok($objects{'_default'}, 'Gestinanna::Package');

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 27 

$objects{'_default'} = Gestinanna::Package -> new(
    name => 'test',
    version => '0.01',
);

isa_ok($objects{'_default'}, 'Gestinanna::Package');
is($objects{'_default'} -> name, 'test');
is($objects{'_default'} -> version, '0.01');

ok($objects{'_default'} -> has_file('conf/package.conf'));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('new');
my @ids = qw(_default);


# method: new

$builder -> begin_tests('new');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 27 

$objects{'_default'} = Gestinanna::Package -> new(
    name => 'test',
    version => '0.01',
);

isa_ok($objects{'_default'}, 'Gestinanna::Package');
is($objects{'_default'} -> name, 'test');
is($objects{'_default'} -> version, '0.01');

ok($objects{'_default'} -> has_file('conf/package.conf'));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('new');

# method: notes

$builder -> begin_tests('notes');


$builder -> end_tests('notes');

# method: open

$builder -> begin_tests('open');


$builder -> end_tests('open');

# method: parse_conf

$builder -> begin_tests('parse_conf');


$builder -> end_tests('parse_conf');

# method: support_email

$builder -> begin_tests('support_email');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 181 

$objects{'_default'} -> support_email('email@some.where');
is($objects{'_default'} -> support_email, 'email@some.where');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('support_email');

# method: type

$builder -> begin_tests('type');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 86 

eval {
    $objects{'_default'} -> type ('foo');
};

my $e = $@;
ok($e && $e =~ m{^Unknown package type:});

eval {
    $objects{'_default'} -> type('application');
};

ok(!$@);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('type');

# method: update_url

$builder -> begin_tests('update_url');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 259 

$objects{'_default'} -> update_url('string');
is($objects{'_default'} -> update_url, 'string');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('update_url');

# method: url

$builder -> begin_tests('url');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 207 

$objects{'_default'} -> url('http://some.url/');
is($objects{'_default'} -> url, 'http://some.url/');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('url');

# method: version

$builder -> begin_tests('version');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 139 


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('version');

# method: write_configuration

$builder -> begin_tests('write_configuration');


$builder -> end_tests('write_configuration');

# method: author_email

$builder -> begin_tests('author_email');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 233 

$objects{'_default'} -> author_email('string');
is($objects{'_default'} -> author_email, 'string');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('author_email');

# method: author_name

$builder -> begin_tests('author_name');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 220 

$objects{'_default'} -> author_name('string');
is($objects{'_default'} -> author_name, 'string');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('author_name');

# method: author_url

$builder -> begin_tests('author_url');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 246 

$objects{'_default'} -> author_url('string');
is($objects{'_default'} -> author_url, 'string');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('author_url');

# method: conf_file

$builder -> begin_tests('conf_file');


$builder -> end_tests('conf_file');

# method: description

$builder -> begin_tests('description');


$builder -> end_tests('description');

# method: devel_email

$builder -> begin_tests('devel_email');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 194 

$objects{'_default'} -> devel_email('email@some.where');
is($objects{'_default'} -> devel_email, 'email@some.where');


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('devel_email');

# method: list_files

$builder -> begin_tests('list_files');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 561 

$objects{'_default'} = Gestinanna::Package -> new( name => 'test', version => '0.01' );
$objects{'_default'} -> type('application');

ok(eq_set([ $objects{'_default'} -> list_files ], [qw(
    conf/package.conf
)]));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('list_files');

# method: name

$builder -> begin_tests('name');


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 120 

$objects{'_default'} -> name("testing$$");
is($objects{'_default'} -> name, "testing$$");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


$builder -> end_tests('name');

# method: create

$builder -> begin_tests('create');


$builder -> end_tests('create');

# method: has_file

$builder -> begin_tests('has_file');


$builder -> end_tests('has_file');

# method: add_file

$builder -> begin_tests('add_file');


$builder -> end_tests('add_file');

# method: add_files_from_tags

$builder -> begin_tests('add_files_from_tags');


$builder -> end_tests('add_files_from_tags');

# method: get_content

$builder -> begin_tests('get_content');


$builder -> end_tests('get_content');

# method: security

$builder -> begin_tests('security');


$builder -> end_tests('security');

# method: security_struct

$builder -> begin_tests('security_struct');


$builder -> end_tests('security_struct');

# method: urls

$builder -> begin_tests('urls');


$builder -> end_tests('urls');

# method: write_package

$builder -> begin_tests('write_package');


$builder -> end_tests('write_package');

# method: embeddings

$builder -> begin_tests('embeddings');


$builder -> end_tests('embeddings');

# method: url_struct

$builder -> begin_tests('url_struct');


$builder -> end_tests('url_struct');

# method: embedding_struct

$builder -> begin_tests('embedding_struct');


$builder -> end_tests('embedding_struct');

# method: install

$builder -> begin_tests('install');


$builder -> end_tests('install');
# record test results for report
$builder -> record_test_details('Gestinanna::Package');
my $tester = Test::More -> builder;
if($tester -> current_test == 0) {
    $tester -> skip_all( 'No tests defined' );
}
