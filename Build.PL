use Module::Build;

my $m = Module::Build -> new(
    module_name => 'Gestinanna',
    module_version_from => 'lib/Gestinanna.pm',
    license => 'perl',
    requires => {
        Alzabo => 0.67,
        Data::UUID => 0,
        Email::Valid => 0,
        Error => 0.15,
        Expect => 0, # for testing
        IO::Pty => 0, # for testing with Expect
        Lingua::EN::Inflect => 1.88,
        Lingua::Preferred => 0.2,
        Mail::Sendmail => 0,
        Gestinanna::POF => 0.06,
        Gestinanna::POF::Repository => 0.03,
        Template => undef,
        XML::LibXML => undef,
    },
# only if the grammer is modified - a parser should be included in the distribution
#    build_requires => {
#        Parse::Yapp => undef,
#    },
    recommends => {
        #Net::Jabber => 0,
        DBD::SQLite => 0,
    },
    create_makefile_pl => undef,
    PL_files => {
        'parser.PL' => 'lib/Gestinanna/XSM/Expression/Parser.pm',
    },
);

$m -> create_build_script;

#WriteMakefile(
#    NAME => 'Gestinanna',
#    VERSION_FROM => 'lib/Gestinanna.pm',
#    PREREQ_PM => {
#    },
#    dist => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
#);

# Note the literal tabes herein
#sub MY::postamble { return $have_yapp ? <<'POSTAMBLE_END' : '' }
#lib/Data/DPath/Parser.pm : dpath.yp
#       yapp -m Data::DPath::Parser \
#               -o lib/Data/DPath/Parser.pm \
#               -s \
#               dpath.yp
#
#dpath.output: dpath.yp
#       yapp -v dpath.yp
#
#dpath.png: dpath.output
#       $(PERL) -MGraphViz::Parse::Yapp \
#               -e 'binmode STDOUT; print GraphViz::Parse::Yapp->new( "dpath.output" )->as_png' \
#               > dpath.png
#
#dpath.dot: dpath.output
#       $(PERL) -MGraphViz::Parse::Yapp \
#               -e 'binmode STDOUT; print GraphViz::Parse::Yapp->new( "dpath.output" )->as_dot' \
#               > dpath.dot
#
#POSTAMBLE_END

