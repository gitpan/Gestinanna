use lib q{t/lib};
use My::Builder;
use Test::More tests => 41;

BEGIN {
    our @modules = qw(
        Gestinanna::Exception
        Gestinanna::POF::Secure::Gestinanna::RepositoryObject
        Gestinanna::Package
        Gestinanna::PackageManager
        Gestinanna::Shell::Base
        Gestinanna::Upload
        Gestinanna::Util
        Gestinanna::XSM::Expression
        Gestinanna::XSM::Expression::Parser
        Gestinanna::XSM::LibXMLSupport
        Gestinanna::XSM::Script
        Gestinanna::SchemaManager
        Gestinanna::SchemaManager::Schema
        Gestinanna::Shell
        Gestinanna::Shell::Package
        Gestinanna::Shell::Schema
        Gestinanna::Shell::Site
        Gestinanna
        Gestinanna::Authz
        Gestinanna::POF::Secure::Gestinanna
        Gestinanna::Request
        Gestinanna::SiteConfiguration
        Gestinanna::XSM::Base
        Gestinanna::XSM::StateMachine
        Apache::Template::Provider::Gestinanna
        Gestinanna::ContentProvider
        Gestinanna::ContentProvider::Document
        Gestinanna::ContentProvider::Portal
        Gestinanna::ContentProvider::TT2
        Gestinanna::XSM
        Gestinanna::XSM::Auth
        Gestinanna::XSM::Authz
        Gestinanna::XSM::ContentProvider
        Gestinanna::XSM::Diff
        Gestinanna::XSM::Digest
        Gestinanna::XSM::Gestinanna
        Gestinanna::XSM::POF
        Gestinanna::XSM::SMTP
        Gestinanna::XSM::Workflow
        Gestinanna::XSM::XMLSimple
        Gestinanna::ContentProvider::XSM
    );

    use_ok($_) for @modules;
}

# record test results for later

my $tester = Test::More -> builder;
my $builder = My::Builder -> current;
my @details = $tester -> details;
my $test_results = $builder -> notes('test_results') || { };

for(my $i = 0; $i <= $#modules; $i++) {
    $test_results -> {$modules[$i]} -> {compile_ok} =
        $details[$i] -> {actual_ok};
}

$builder -> notes(test_results => $test_results);
