use lib 't/lib';
use My::Builder;

my $m = My::Builder -> new(
    module_name => 'Gestinanna',
    module_version_from => 'lib/Gestinanna.pm',
    license => 'perl',
    requires => {
        Alzabo => 0.82,
        Archive::Tar => 0,
        Data::UUID => 0,
        Email::Valid => 0,
        Error => 0.15,
        Lingua::EN::Inflect => 1.88,
        Lingua::Preferred => 0.2,
        Mail::Sendmail => 0,
        Module::Require => 0.05,
        Gestinanna::POF => 0.06,
        Gestinanna::POF::Repository => 0.03,
        Template => undef,
        XML::LibXML => undef,
        Workflow => 0.03,
    },
# only if the grammer is modified - a parser should be included in the distribution
#    build_requires => {
#        Parse::Yapp => undef,
#    },
    recommends => {
        #Net::Jabber => 0,
        DBD::SQLite => 0,
        Expect => 0, # for testing
        IO::Pty => 0, # for testing with Expect
        Term::Size => 0.2, # for shell
    },
    create_makefile_pl => undef,
    PL_files => {
        'parser.PL' => 'lib/Gestinanna/XSM/Expression/Parser.pm',
    },
);

$m -> create_build_script;
