use lib q{t/lib};
use My::Builder;use Test::More;

# Cleanup for Gestinanna::SchemaManager::Schema

use Gestinanna::SchemaManager::Schema;

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;
#line 42 

use Gestinanna::SchemaManager;

Gestinanna::SchemaManager -> _load_runtime;
Gestinanna::SchemaManager -> _load_create;
$Alzabo::Config::CONFIG{'root_dir'} = 'alzabo';

eval {
    my $schema = Gestinanna::SchemaManager -> new -> create_schema(name => 'test', rdbms => 'SQLite');
    $schema -> drop;
    $schema -> delete;
};


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}


plan skip_all => 'No tests defined';
