#! perl

my $SchemaName = 'Gestinanna';
my $UserName = 'username';
my $Password = 'password';
my $Host = 'host';

use Gestinanna::Schema;
use Gestinanna::POF;

Gestinanna::Schema -> make_methods(
    name => $SchemaName,
);

my $schema = Gestinanna::Schema -> load_schema(
    name => $SchemaName,
    user => $UserName,
    password => $Password,
    host => $Host
);

my $site = $schema -> table('Site') -> row_by_pk( pk => 1 );

my $configuration = <<'EOXML';
<configuration
  package="Gestinanna::Sites::Mine"
>
  <tag-path>
    <tag>production_tag</tag>
  </tag-path>
  <session >
    <cookie name="SESSION_ID"/>
    <store
      store="MySQL"
      lock="MySQL"
      generate="MD5"
      serialize="Storable"
    />
  </session>
  <content-provider
    type="document"
    class="Gestinanna::ContentProvider::Document"
  />

  <!--
     provides content of type xsm
     default data provider is `xsm'
     base class is Gestinanna::ContentProvider::XSM
     uses views from the `view' content provider
     uses data provider `context' to manage contexts
     caches compiled xsm in /data/gst_xsm
    -->
  <content-provider
    type="xsm"
    class="Gestinanna::ContentProvider::XSM"
    view-type="view"
    context-type="context"
  >
    <cache dir="/data/gst_xsm"/>
  </content-provider>

  <!--
     provides content of type view
     default data provider is `view'
     base class is Gestinanna::ContentProvider::TT2
    -->
  <content-provider
    type="view"
    class="Gestinanna::ContentProvider::TT2"
  />

  <content-provider
    type="portal"
    class="Gestinanna::ContentProvider::Portal"
  />

  <!--
     provides data of type xsm
     stores the data in a repository
     the base name for the repository tables is XSM
     uses read-write security
    -->
  <data-provider
    type="xsm"
    data-type="repository"
    repository="XSM"
    description="eXtensible State Machine"
    security="read-write"
  />

  <data-provider
    type="document"
    data-type="repository"
    repository="Document"
    description="Document"
    security="read-write"
  />
  <data-provider
    type="portal"
    data-type="repository"
    repository="Portal"
    description="Portal"
    security="read-write"
  />
  <data-provider
    type="view"
    data-type="repository"
    repository="View"
    description="View"
    security="read-write"
  />

  <!--
     provides data of type context
     stores data in an RDBMS table using Alzabo
     uses the table named Context
    -->
  <data-provider
    type="context"
    data-type="alzabo"
    table="Context"
  />

  <data-provider
    type="site"
    data-type="alzabo"
    table="Site"
  />
  <data-provider
    type="uri-map"
    data-type="alzabo"
    table="Uri_Map"
  />
  <data-provider
    type="user"
    data-type="alzabo"
    table="User"
    security="read-write"
  />

  <!-- an actor is a read-only user object, basicly -->
  <data-provider
    type="actor"
    data-type="alzabo"
    table="User"
    security="read-only"
  />

  <data-provider
    type="username"
    data-type="alzabo"
    table="Username"
    security="read-write"
  />
  <data-provider
    type="xslt"
    data-type="repository"
    repository="XSLT"
    description="XSLT"
    security="read-write"
  />
  <data-provider
    type="folder"
    data-type="alzabo"
    table="Folder"
    security="read-write"
  />
</configuration>
EOXML

if($site -> is_live) {
    $site -> update(configuration => $configuration);
}
else {
    warn "Need to  create site 1 using gst-manage\n";
}
