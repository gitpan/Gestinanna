use Test::More;

# do things load?

my @classes = qw(
    Gestinanna
    Gestinanna::Schema
    Gestinanna::Schema::Base
    Gestinanna::Schema::Authz
    Gestinanna::Schema::Context
    Gestinanna::Schema::Document
    Gestinanna::Schema::Portal
    Gestinanna::Schema::Preference
    Gestinanna::Schema::Repository
    Gestinanna::Schema::Session
    Gestinanna::Schema::Site
    Gestinanna::Schema::Upload
    Gestinanna::Schema::User
    Gestinanna::Schema::View
    Gestinanna::Schema::XSLT
    Gestinanna::Schema::XSM
    Gestinanna::XSM
    Gestinanna::XSM::Base
    Gestinanna::ContentProvider
    Gestinanna::ContentProvider::XSM
    Gestinanna::ContentProvider::Portal
);

plan tests => scalar(@classes);

my $e;

foreach my $class (@classes) {
    eval "require $class;";
    $e = $@; diag($e) if $e;
    ok(!$e, "Requiring $class");
}
