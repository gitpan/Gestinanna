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

my $factory = Gestinanna::POF -> new( _factory => (
    alzabo_schema => $schema,
    tag_path => [ 'UNKNOWN' ],
) );

for $rep (qw(Portal Document View XSM XSLT)) {
    eval <<1HERE1;
package My::$rep;

use Gestinanna::POF::Repository "$rep",
    object_classes => [qw(Gestinanna::POF::Secure::Gestinanna::RepositoryObject)]
;

\$INC{'My/$rep.pm'} = 1;  # for Class::Factory 's benefit
1HERE1

    warn "$@\n" if $@;

    eval qq{My::$rep -> add_factory_types( \$factory, '} . lc($rep) . q{' );};
    warn "$@\n" if $@;
}

my $base = '/sys/file-manager';
my $secure = "/sys/secure";

%docs = (
    document => {

        "$base/manage/templates/xsm" => <<'EOXML',
<statemachine
  xmlns="http:///ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
>
  <alias id="_begin" state="start"/>

  <script when="pre">
    <!-- state machine initialization code goes here -->
  </script>

  <state id="start">
    <transition state="next">
      <variable id="something">
        <filter id="trim"/>
      </variable>

      <script>
        <!-- this gets run when you go from `start' to `next' -->
      </script>
    </transition>
  </state>

</statemachine>
EOXML

        "$base/manage/templates/document" => <<'EOXML',
<container>
  <title>Title of Document</title>
  <content>
    <para>
This is the content of the document.  The markup is based on DocBook, 
but with some changes.
    </para>
  </content>
</container>
EOXML

        "$base/manage/templates/view" => <<'EOXML',
<container>
  <title>Title of View</title>
  <content>
    <para>
This is the content of the view.  The markup is based on DocBook, but 
with some changes; most notably forms.  This document is passed through 
Template Toolkit before being passed on to AxKit for further processing.
    </para>
    <form>
      <caption>Caption of a Form</caption>
      <textline id="something">
        <caption>Something:</caption>
        <default>Default Value</default>
      </textline>
      <submit id="action.doit"><caption>Do It!</caption></submit>
      <reset/>
    </form>
  </content>
</container>
EOXML

        "$base/manage/templates/portal" => <<'EOXML',
<container>
  <title>Title of Portal Page</title>
  <content>
    <para>
This is the content of the portal page.  The markup is based on 
DocBook, but with some changes; most notably content embedding.
    </para>
    <para>
Use the &lt;container/&gt; element with a @uuid attribute to embed 
another object in the page.  For example, to embed a state machine, 
use something like &lt;container uuid="some_id" type="xsm" 
id="/path/to/xsm/object"/&gt; .  The @uuid attribute value should be 
unique in a page.
    </para>
  </content>
</container>
EOXML
    },

    portal => {

    '/theme/_default/frame' => <<'EOXML',
<container>
  <head>
    <container uuid="login" type="xsm" id="/sys/secure/login"/>
  </head>
  <content>
    <container id="_embedded"/>
  </content>
</container>
EOXML

    },

    view => {

        '/sys/default/_debug' => <<'EOXML',
<container>
  <title>Oops!</title>
  <content>
    <para>
Looks like we had an error.
    </para>
    <important><title>Error!</title><para>[% _error | html %]</para></important>
  </content> 
</container>
EOXML

###
### User Management
###
        "$secure/login/logged_out" => <<'EOXML',
<container>
  <content>
    <form>
      <textline id="username">
        <caption>Username:</caption>
      </textline>
      <password id="password">
        <caption>Password:</caption>
      </password>
      <submit id="action.login"><caption>Login</caption></submit>
    </form>
    <link url="/acct/create.xml">Create Account</link>
  </content>
</container>
EOXML
    
        "$secure/login/logged_in" => <<'EOXML',
<container>
  <content>
    <para>You are logged in.</para>
    <form>
      <submit id="action.logout"><caption>Logout</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$secure/user/create/email" => <<'EOMAIL',
Test...

Supposed to go to <[% email %]>.

Go the the following URL to confirm receipt of this e-mail.

URL: (site root)/acct/confirm/[% password_check %]

--EOMAIL--
EOMAIL

  "$secure/user/create/step_1" => <<'EOXML',
<container>
  <title>Create Account</title>
  <content>
    [% IF messages.error %]
      <important><title>Error!</title><para>[% messages.error | html %]</para></important>
    [% END %]
    <form>
      <textline id="username" required="1">
        <caption>Username:</caption>
      </textline>
      <textline id="email" required="1">
        <caption>E-mail Address:</caption>
      </textline>
      <password id="password1" required="1">
        <caption>Password:</caption>
      </password>
      <password id="password2" required="1">
        <caption>Password Again:</caption>
      </password>
      <submit><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

  "$secure/user/create/select_username" => <<'EOXML',
<container>
  <title>Create Account</title>
  <content>
    <para>
The username you selected is already taken.  Please select a different
one or return to the previous screen to start over.
    </para>
    <form>
      <textline id="username" required="1">
        <caption>Username:</caption>
      </textline>
      <submit><caption>Continue</caption></submit>
      <submit id="action"><caption>Start Over</caption></submit>
    </form>
  </content>
</container>
EOXML

  "$secure/user/create/confirm" => <<'EOXML',
<container>
  <title>Create Account</title>
  <content>
    <para>
Please confirm that the following information is correct.  If
everything is correct, select `Finish.'  An e-mail will be sent to your
e-mail address with a URL to confirm the creation of this account.  You
will need to go to that URL before you will be able to login.
    </para>
    <variablelist>
      <varlistentry>
        <term>Username</term>
        <listitem>[% out.username | html %]</listitem>
      </varlistentry>
      <varlistentry>
        <term>E-mail Address</term>
        <listitem>[% out.email | html %]</listitem>
      </varlistentry>
    </variablelist>
    <form>
      <submit id="action"><caption>Prev</caption></submit>
      <submit id="action"><caption>Finish</caption></submit>
    </form>
  </content>
</container>
EOXML

  "$secure/user/create/finish" => <<'EOXML',
<container>
  <title>Create Account</title>
  <content>
    <para>
An e-mail has been sent to your e-mail account.  Please go to the URL
listed in the e-mail.  This will finish creating your account.  If you
ever forget your password, you will be able to use that same URL to
set a new password.
    </para>
  </content>
</container>
EOXML

  "$secure/user/confirm/activate" => <<'EOXML',
<container>
  <title>Account Access</title>
  <content>
    <para>
If you are finishing setting up an account or have forgotten your password, enter your username and e-mail address below to continue
.   
    </para>
    <form>
      <textline id="username">
        <caption>Username:</caption>
        <default>[% out.username | html %]</default>
      </textline>
      <textline id="email">
        <caption>E-Mail:</caption>
      </textline>
      <submit><caption>Submit</caption></submit>
    </form>
  </content>
</container>
EOXML

  "$secure/user/confirm/finish" => <<'EOXML',
<container>
  <title>Account Access</title>
  <content>
    <para>
Your account is now ready to use.  If you forget your password, you may return to this URL and set a new one.
    </para>
  </content>
</container>
EOXML

  "$secure/user/confirm/set_password" => <<'EOXML',
<container>
  <title>Account Access</title>
  <content>
    <form>
      <password id="password1">
        <caption>Password:</caption>
      </password>
      <password id="password2">
        <caption>Password Again:</caption>
      </password>
      <submit/>
    </form>
  </content>
</container>
EOXML

  "$secure/user/confirm/finish_password" => <<'EOXML',
<container>
  <title>Account Access</title>
  <content>
    <para>
Your password has been changed.
    </para>
  </content>
</container>
EOXML


###
### Configuration Views
###

        "$secure/configure/site_list" => <<'EOXML',
<container>
  <title>Site Management</title>
  <content>
    <!-- sites => { site => #, name => # } -->
    <form>
      [% IF out.sites.size %]
        <selection count="multiple" id="site">
          [% FOREACH site IN out.sites %]
          <option id="[% site.key %]">
            <caption>[% site.key %] - [% site.value %]</caption>
          </option>
          [% END %]
        </selection>
        <text>
          <para>
Select a single site to edit or any number of sites to delete.
Be careful deleting a site since it won't come back without a lot of
hard work.  You may also add a site without selecting an existing site,
though a single selected site will serve as a template.  You may not
delete the configuration for this site.
          </para>
        </text>
      [% ELSE %]
        <text>
          <para>
You need to add a site.
          </para>
        </text>
      [% END %]
      <submit id="action.add"><caption>Add</caption></submit>
      [% IF out.sites.size %]
        <submit id="action.edit"><caption>Edit</caption></submit>
      [% END %]
      [% IF out.sites.size > 1 %]
        <!-- submit id="action.delete"><caption>Delete</caption></select -->
      [% END %]
    </form>
  </content>
</container>
EOXML

        "$secure/configure/site_edit" => <<'EOXML',
<container>
  <title>Site Management</title>
  <content>

    <form>
      <caption>Editing [% out.siteinfo.name %]</caption>

      <textline id="name">
        <caption>Configuration name:</caption>
        <default>[% out.siteinfo.name %]</default>
      </textline>

      <textline id="package">
        <caption>Perl package:</caption>
        <default>[% out.siteinfo.config.package %]</default>
      </textline>
                
      <form id="session">
        <caption>Session</caption>
          
        <textline id="cookie.name">
          <caption>Cookie name:</caption>
          <default>[% out.siteinfo.config.session.cookie.name %]</default>
        </textline>
            
        <form id="store">
          <caption>Store</caption>
                
          <textline id="store"><!-- /session/store/store -->
            <caption>store:</caption>
            <default>[% out.siteinfo.config.session.store.store %]</default>
          </textline>
        
          <textline id="lock"><!-- /session/store/lock -->
            <caption>lock:</caption>
            <default>[% out.siteinfo.config.session.store.lock %]</default>
          </textline>
              
          <textline id="generate"><!-- /session/store/generate -->
            <caption>generate:</caption>
            <default>[% out.siteinfo.config.session.store.generate %]</default>
          </textline>   
            
          <textline id="serialize"><!-- /session/store/serialize -->
            <caption>serialize:</caption>
            <default>[% out.siteinfo.config.session.store.serialize %]</default>
          </textline>
        
        </form>     
      
      </form>
    
      <form id="tag-path">
        <caption>Tag Path</caption>
        <group id="0">
          <caption>New head:</caption>
          <selection id="tag"> <!-- want all tags not denoted as being a user or already in the list -->
            <default/>
            <option id=""><caption>-none-</caption></option>
            <option id="Foo"><caption>Foo</caption></option>
            <option id="Bar"><caption>Bar</caption></option>
          </selection>
          <submit id="action.add"><caption>Add</caption></submit>
        </group>
        [% SET tp = "tag-path" %]
        [% FOREACH tag IN out.siteinfo.config.$tp %]
          <group id="[% loop.count() %]">
            <caption>[% tag.tag %]</caption>
            <submit id="action.delete"><caption>Delete</caption></submit>
            <submit id="action.promote"><caption>Promote</caption></submit>
            <submit id="action.demote"><caption>Demote</caption></submit>
          </group>
        [% END %]
      </form>

      <form id="content-provider">
        <caption>Content Providers</caption>

        <selection count="multiple" id="selection">
          [% SET providers = "content-provider" %]
          [% FOREACH provider IN out.siteinfo.config.$providers.keys %]
            <option id="[% provider %]">
              <caption>[% provider %]</caption>
            </option>
          [% END %]
        </selection>

        <submit id="action.add"><caption>Add</caption></submit>
        <submit id="action.edit"><caption>Edit</caption></submit>
        <submit id="action.delete"><caption>Delete</caption></submit>

      </form>

      <form id="data-provider">
        <caption>Data Providers</caption>

        <selection count="multiple" id="selection">
          [% SET providers = "data-provider" %]
          [% FOREACH provider IN out.siteinfo.config.$providers.keys %]
            <option id="[% provider %]">
              <caption>[% provider %]</caption>
            </option>
          [% END %]
        </selection>

        <submit id="action.add"><caption>Add</caption></submit>
        <submit id="action.edit"><caption>Edit</caption></submit>
        <submit id="action.delete"><caption>Delete</caption></submit>

      </form>
      <submit id="action.next"><caption>Done</caption></submit>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <reset/>

    </form>

  </content>
</container>
EOXML

        "$secure/configure/clone_site" => <<'EOXML',
<container>
  <title>Site Management</title>
  <content>
    <form>
      <caption>Clone [% out.siteinfo.name %]</caption>
      <text><para>
All information from [% out.siteinfo.name %] will be copied into a new site configuration.
      </para></text>
      <textline id="name">
        <caption>Name of new site:</caption>
        <default>[% out.siteinfo.name %]</default>
      </textline>
      <submit id="action.next"><caption>Continue</caption></submit>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$secure/configure/create_site" => <<'EOXML',
<container>
  <title>Site Management</title>
  <content>
    <form>
      <caption>Create New Site Configuration<caption>
      <text><para>
The new site configuration will be empty.
      </para></text>
      <textline id="name">
        <caption>Name of new site:</caption>
        <default>[% out.siteinfo.name %]</default>
      </textline>
      <submit id="action.next"><caption>Continue</caption></submit>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$secure/configure/confirm_edits" => <<'EOXML',
<container>
  <title>Site Management</title>
  <content>
    <para>XML Configuration for [% out.siteinfo.name %]</para>
    <screen>[% out.siteinfo.configxml | html %]</screen>
    <form>
      <submit id="action.next"><caption>Confirm</caption></submit>
      <submit id="action.prev"><caption>Edit</caption></submit>
      <submit id="action.discard"><caption>Drop Changes</caption></submit>
    </form>
  </content>
</container>
EOXML

## data provider and content provider editing is best left to the xsm for that type
##   $secure/configure/data-provider/$type
##   $secure/configure/content-provider/$type
## support: POF (Alzabo, Net::LDAP, combinations, repository, remote), Custom Perl Class
       

###
### File Manager Views
###
        "$base/manage/xsm/wizard/view" => <<'EOXML',
[% TAGS (* *) %]
<container>
  <title>(* title | html *)</title>
  <content>
    <form><caption>Step (* step + 1 | html *) of (* steps + 1 | html *)</caption>
      (* FOREACH variables *) 
        <(* type.value *) id="(* id | html *)" 
          (*- IF dependence == "required" *) required="1" (* END -*)
          (*- IF type.value == "selection" && count == "multiple" -*) count="multiple" (*- END -*)
        >
          <caption>(* IF caption *)(* caption | html *)(* ELSE *)(* id | html *)(* END *):</caption>
          (* IF type.value == "selection" *)
            (* FOREACH option IN type.selection.options *)
              <option id="(* option | html *)"><caption>(* option | html *)</caption></option>
            (* END *)
          (* END *)
        </(* type.value *)>
      (* END *)
      [% INCLUDE buttons step=(* step+1 *), steps=(* steps+1 *) %]
    </form>
  </content>
</container>
EOXML

        "/sys/xsm/wizard/buttons" => <<'EOXML',
[% IF step > 1 %]
  <submit id="action.prev">
    <caption>Previous</caption>
  </submit>
[% END %]
<reset/>
<submit id="action.discard">
  <caption>Cancel</caption>
</submit>
[% IF step < steps %]
  <submit id="action.next">
    <caption>Next</caption>
  </submit>
[% ELSIF step == steps %]
  <submit id="action.next">
    <caption>Finish</caption>
  </submit>
[% END %]
EOXML

        "/sys/xsm/wizard/finish" => <<'EOXML',
[% USE dumper %]
<container>
  <title>Dump of Collected Data</title>
  <content>
    <para>
The following information was collected by this wizard.  This page is 
for testing purposes only.  This view may be replaced by creating a 
`finish' view specific to this wizard.
    </para>
    <screen>[%- dumper.dump(out) | html -%]</screen>
    <form><submit id="action.discard"><caption>Cancel</caption></submit><submit id="action.done"><caption>Done</caption></submit></form>
  </content>
</container>
EOXML

        "$base/manage/xsm/wizard/xsm" => <<'EOXML',
<?xml-stylesheet file="/sys/xsm/wizard" type="xslt" ?>
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:wiz="http://ns.gestinanna.org/xsm/xsl/wizard"
>
  <wiz:steps>
    [% FOREACH filter IN filters %]
      <filter id="[% filter | html %]"/>
    [% END %]

    [% FOREACH steps %]
      <wiz:step [% IF view %] view="[% view | html %]" [% END %]>
        [% FOREACH filter IN filters %]
          <filter id="[% filter | html %]"/>
        [% END %]
        [% FOREACH variables %]
          <variable id="[% id | html %]" [% IF dependence == "optional" %] dependence="OPTIONAL" [% END %]>
            [% FOREACH filter IN filters %]
              <filter id="[% filter | html %]"/>
            [% END %]
            [% FOREACH constraints.id %]
                <constraint id="[% id | html %]"/>
            [% END %]
            [% IF constraints.min_length %]
              <constraint min-length="[% constraints.min_length %]"/>
            [% END %]
            [% IF constraints.max_length %]
              <constraint max-length="[% constraints.max_length %]"/>
            [% END %]
            [% IF constraints.length %]
              <constraint length="[% constraints.length %]"/>
            [% END %]
            [% IF constraints.equal %]
              <constraint equal="[% constraints.equal %]"/>
            [% END %]
          </variable>
        [% END %]
      </wiz:step>
    [% END %]
  </wiz:steps>

  <state id="finish">
    <script when="pre">
      <!-- put your code here to do something with the information 
           you've gathered
         -->
    </script>
  </state>
</statemachine>
EOXML

        "$base/manage/folder/create" => <<'EOXML',
<container>
  <title>Create New Folder</title>
  <content>
    <form>
      <textline id="filename" size="80"><caption>Folder name:</caption></textline>
      <textline id="description" size="80"><caption>Description:</caption></textline>
      <submit id="action.finish"><caption>Create Folder</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/manage/document/create" => <<'EOXML',
<container>
  <title>Create New Object</title>
  <content>
    <form>
      <text>
        <caption>Type:</caption>
        [% out.type %]
      </text>
      <textline id="filename" size="80"><caption>Filename:</caption></textline>
      <textline id="description" size="80"><caption>Description:</caption></textline>
      <submit id="action.next"><caption>Next</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/manage/document/create_edit" => <<'EOXML',
<container>
  <title>Create New Object</title>
  <content>
    <form>
      <text>
        <caption>Type:</caption>
        [% out.type %]
      </text>
      <text>
        <caption>Filename:</caption>
        [% out.filename %]
      </text>
      <text>
        <caption>Description:</caption>
        [% out.description %]
      </text>
      <editbox id="data"/>
      <submit id="action.save"><caption>Save</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/manage/document/edit" => <<'EOXML',
<container>
  <title>Edit Object</title>
  <content>
    <form>
      <text>
        <caption>Type:</caption>
        [% out.path.type %]
      </text>
      <text>
        <caption>Filename:</caption>
        [% out.path.name %]
      </text>
      <text>
        <caption>Description</caption>
        [% out.description %]
      </text>
      <textline id="log" size="80"><caption>Log:</caption></textline>
      <editbox id="data"/>
      <submit id="action.save"><caption>Save</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/manage/document/view" => <<'EOXML',
<container>
  <title>View Object</title>
  <content>
    <formalpara>
      <caption>Type</caption>
      <para>[% out.path.type | html %]</para>
    </formalpara>
    <formalpara>
      <caption>Filename</caption>
      <para>[% out.path.name | html %]</para>
    </formalpara>
    <formalpara>
      <caption>Description</caption>
      <para>[% out.description | html %]</para>
    </formalpara>
    <formalpara>
      <caption>Log</caption>
      <para>[% out.log | html %]</para>
    </formalpara>
    <screen>[% out.data | html %]</screen>
    <form>
      <submit id="action.discard"><caption>Return to Revision List</caption></submit>
    </form>
  </content>
</container>
EOXML


        "$base/manage/xsm/create" => <<'EOXML',
<container>
  <title>Create New Object</title>
  <content>
    <form>
      <text>
        <caption>Type:</caption>
        xsm
      </text>
      <textline id="filename" required="1"><caption>Filename:</caption></textline>
      <textline id="description"><caption>Description:</caption></textline>
      <selection id="type" required="1"><caption>XSM Type:</caption>
        <option id="plain"><caption>Plain</caption></option>
        <option id="wizard"><caption>Wizard</caption></option>
      </selection>
      <submit id="action.next"><caption>Next</caption></submit>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <reset/>
    </form>
  </content>
</container>
EOXML

        "$base/manage/xsm/wizard/steps" => <<'EOXML',
<container>
  <title>Create New XSM Wizard</title>
  <content>
    <form>
      <textline id="title"><caption>Title:</caption></textline>
      <form><caption>Steps</caption>
        [% IF out.data.steps %]
          <selection id="steps" count="multiple">
            [% FOREACH out.data.steps %]
              <option id="[% loop.index() %]">
                <caption>
                  Step [% loop.index() + 1 %]
                  [% IF view %]
                    - [% view | html %]
                  [% END %]
                </caption>
              </option>
            [% END %]
          </selection>
        [% ELSE %]
          <text><para>
You need to add a step.
          </para></text>
        [% END %]
        <submit id="action.add"><caption>[% IF out.data.steps %] Append [% ELSE %] Add [% END %]</caption></submit>
        [% IF out.data.steps %]
          <submit id="action.add.before"><caption>Add Before</caption></submit>
          <submit id="action.add.after"><caption>Add After</caption></submit>
          <submit id="action.edit"><caption>Edit</caption></submit>
        [% END %]
        <reset/>
        [% IF out.data.steps %]
          <submit id="action.delete"><caption>Delete</caption></submit>
        [% END %]
      </form>
      <form><caption>Filters</caption>
        <text><para>
Select those filters which you want applied to <emphasize>all</emphasize> 
data coming from the customer's browser <emphasize>for all steps</emphasize>.
        </para></text>
[% filter = [
    { id => 'trim', description => 'trim leading/trailing whitespace' },
    { id => 'strip', description => 'compact whitespace' },
    { id => 'lc', description => 'make lowercase' },
    { id => 'uc', description => 'make uppercase' },
    { id => 'digit', description => 'extract digits' },
    { id => 'alphanum', description => 'extract alphanumerics' },
    { id => 'integer', description => 'extract a valid integer' },
    { id => 'pos_integer', description => 'extract a positive integer' },
    { id => 'neg_integer', description => 'extract a negative integer' },
    { id => 'decimal', description => 'extract a decimal number' },
    { id => 'pos_decimal', description => 'extract a positive decimal number' },
    { id => 'neg_decimal', description => 'extract a negative decimal number' },
    { id => 'dollars', description => 'extract a valid number representing a dollars-like currency' },
    { id => 'phone', description => 'extract a phone number' },
    { id => 'sql_wildcard', description => 'transform a shell glob "*" into an SQL wildcard "%"' },
    { id => 'quotemeta', description => 'quote meta characters' },
    { id => 'ucfirst', description => 'upper case leading character' },
    { id => 'gst:multiline', description => 'transform multiline input into multiple values' },
] %]
        <selection id="filters" count="multiple">
          [% FOREACH filter %]
            <option id="[% id | html %]"><caption>[% description | html %]</caption></option>
          [% END %]
        </selection>
      </form>
      <submit id="action.save"><caption>Save</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/manage/xsm/wizard/edit_step" => <<'EOXML',
<container>
  <title>Create New XSM Wizard</title>
  <content>
    <form>
      <form><caption>Variables</caption>
        [% IF out.step.variables %]
          <selection id="variables" count="multiple">
            [% FOREACH out.step.variables %]
              <option id="[% loop.index() %]">
                <caption>
                  [% id | html %]
                </caption>
              </option>
            [% END %]
          </selection>
        [% ELSE %]
          <text><para>
You need to add a variable.
          </para></text>
        [% END %]
        <submit id="action.add"><caption>Add</caption></submit>
        [% IF out.step.variables %]
          <submit id="action.edit"><caption>Edit</caption></submit>
        [% END %]
        <reset/>
        [% IF out.step.variables %]
          <submit id="action.delete"><caption>Delete</caption></submit>
        [% END %]
      </form>
      <form><caption>Filters</caption>
        <text><para>
Select those filters which you want applied to <emphasize>all</emphasize> 
data coming from the customer's browser <emphasize>for this step</emphasize>.
        </para></text>
[% filter = [
    { id => 'trim', description => 'trim leading/trailing whitespace' },
    { id => 'strip', description => 'compact whitespace' },
    { id => 'lc', description => 'make lowercase' },
    { id => 'uc', description => 'make uppercase' },
    { id => 'digit', description => 'extract digits' },
    { id => 'alphanum', description => 'extract alphanumerics' },
    { id => 'integer', description => 'extract a valid integer' },
    { id => 'pos_integer', description => 'extract a positive integer' },
    { id => 'neg_integer', description => 'extract a negative integer' },
    { id => 'decimal', description => 'extract a decimal number' },
    { id => 'pos_decimal', description => 'extract a positive decimal number' },
    { id => 'neg_decimal', description => 'extract a negative decimal number' },
    { id => 'dollars', description => 'extract a valid number representing a dollars-like currency' },
    { id => 'phone', description => 'extract a phone number' },
    { id => 'sql_wildcard', description => 'transform a shell glob "*" into an SQL wildcard "%"' },
    { id => 'quotemeta', description => 'quote meta characters' },
    { id => 'ucfirst', description => 'upper case leading character' },
    { id => 'gst:multiline', description => 'transform multiline input into multiple values' },
] %]
        <selection id="step.filters" count="multiple">
          [% FOREACH filter %]
            <option id="[% id | html %]"><caption>[% description | html %]</caption></option>
          [% END %]
        </selection>
      </form>
      <submit id="action.save"><caption>Save Step</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/manage/xsm/wizard/edit_variable" => <<'EOXML',
<container>
  <title>Create New XSM Wizard</title>
  <content>
    <form>
      <textline id="variable.id"><caption>Identifier:</caption></textline>
      <textline id="variable.caption"><caption>Caption:</caption></textline>
      <selection id="variable.dependence"><caption>Dependence:</caption>
        <option id="required"><caption>required</caption></option>
        <option id="optional"><caption>optional</caption></option>
      </selection>
      <selection id="variable.type"><caption>Type:</caption>
        <option id="textline"><caption>Text Line</caption></option>
        <option id="textbox"><caption>Text Area</caption></option>
        <option id="editbox"><caption>Document</caption></option>
        <option id="password"><caption>Password</caption></option>
        <option id="selection">
          <caption>Selection</caption>
          <form>
            <selection id="count">
              <caption>Select:</caption>
              <option id="single"><caption>Single</caption></option>
              <option id="multiple"><caption>Multiple</caption></option>
            </selection>
            <textbox id="options">
              <caption>Valid Options:</caption>
            </textbox>
          </form>
        </option>
      </selection>
      <form id="variable.constraints"><caption>Constraints</caption>
        <selection id="id" count="multiple"><caption>Named Constraints:</caption>
          [% constraints = [
               { id => 'email', description => 'E-Mail' },
               { id => 'state_or_province', description => 'State or Province' },
               { id => 'state', description => 'State' },
               { id => 'province', description => 'Province' },
               { id => 'zip_or_postcode', description => 'Zip or Postcode' },
               { id => 'zip', description => 'Zipcode' },
               { id => 'postcode', description => 'Postcode' },
               { id => 'phone', description => 'Phone Number' },
               { id => 'american_phone', description => 'American Phone Number' },
               { id => 'ip_address', description => 'IP Address' },
               { id => 'gst:filename', description => 'Filename' },
            ] %]
          [% FOREACH constraints %]
            <option id="[% id | html %]"><caption>[% description | html %]</caption></option>
          [% END %]
        </selection>
        <textline id="min_length"><caption>Minimum length:</caption></textline>
        <textline id="max_length"><caption>Maximum length:</caption></textline>
        <textline id="length"><caption>Length:</caption></textline>
        <textline id="equal"><caption>Equal:</caption></textline>
      </form>
      <form><caption>Filters</caption>
        <text><para>
Select those filters which you want applied to <emphasize>all</emphasize>
data coming from the customer's browser <emphasize>for this step</emphasize>.
        </para></text>
[% filter = [
    { id => 'trim', description => 'trim leading/trailing whitespace' },
    { id => 'strip', description => 'compact whitespace' },
    { id => 'lc', description => 'make lowercase' },
    { id => 'uc', description => 'make uppercase' },
    { id => 'digit', description => 'extract digits' },
    { id => 'alphanum', description => 'extract alphanumerics' },
    { id => 'integer', description => 'extract a valid integer' },
    { id => 'pos_integer', description => 'extract a positive integer' },
    { id => 'neg_integer', description => 'extract a negative integer' },
    { id => 'decimal', description => 'extract a decimal number' },
    { id => 'pos_decimal', description => 'extract a positive decimal number' },
    { id => 'neg_decimal', description => 'extract a negative decimal number' },
    { id => 'dollars', description => 'extract a valid number representing a dollars-like currency' },
    { id => 'phone', description => 'extract a phone number' },
    { id => 'sql_wildcard', description => 'transform a shell glob "*" into an SQL wildcard "%"' },
    { id => 'quotemeta', description => 'quote meta characters' },
    { id => 'ucfirst', description => 'upper case leading character' },
    { id => 'gst:multiline', description => 'transform multiline input into multiple values' },
] %]
        <selection id="variable.filters" count="multiple">
          [% FOREACH filter %]
            <option id="[% id | html %]"><caption>[% description | html %]</caption></option>
          [% END %]
        </selection>
      </form>
      <submit id="action.save"><caption>Save Variable</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/file_list" => <<'EOXML',
<container>
  <title>File Manager - [% out.path.name | html %][% IF out.path.type != "folder" %].[% out.path.type | html %][% END %]</title>
  <head><!-- do we want this to be a different state machine? -->
    [% IF out.types.size %]
      <form>
        <selection id="type">
          <!-- option id="folder"><caption>Folder</caption></option -->
          [% FOREACH type IN out.types %]
            <option id="[% type.key %]"><caption>[% type.value %]</caption></option>
          [% END %]
        </selection>
        <submit id="action.create"><caption>Create</caption></submit>
      </form>
    [% END %]
  </head>
  <content>
    <table id="listing">
      <tgroup>
      <thead sort="[% out.listing.sort %]" order="[% out.listing.sortorder %]">
        <column width="10%">Status</column>
        <column width="20%" id="name">Name</column>
        <!-- column width="10%" id="last-modified">Last Modified</column -->
        <column width="20%">Options</column>
        <column width="30%">Description</column>
      </thead>
      <!-- probably want to be able to sort on different columns -->
      [% IF in.sys.path_info != '' && in.sys.path_info != '/' %]
        <row>
          <column/>
          <column><link url="../">../</link></column>
          <column/>
          <column/>
        </row>
      [% END %]
      [% FOREACH file IN out.files.sort('name') %]
        <row>
          <column>
          </column>
          <column>
            [% IF file.type == "folder" %]
              <link url="[% file.name | html %]/">[% file.name | html %]/</link>
            [% ELSE %]
              <link url="[% file.name | html %].[% file.type | html %]">[% file.name | html %] ([% file.type | html %])</link>
            [% END %]
          </column>
          <!-- column>
            [% IF file.type != "folder" %]
              [% file.last_modified.month %]/[% file.last_modified.day %]/[% file.last_modified.year %]
              [% file.last_modified.hour %]:[% file.last_modified.minute %]:[% file.last_modified.second %]
            [% END %]
          </column -->
          <column>
          </column>
          <column>
            [% file.description | html %]
          </column>
        </row>
      [% END %]
       </tgroup>
     </table>
  </content>
</container>
EOXML

        "$base/revision_list" => <<'EOXML',
<container>
  <title>File Manager - [% out.path.name | html %][% IF out.path.type != "folder" %].[% out.path.type | html %][% END %]</title>
  <head>
  [% IF out.revisions.size > 1 %]
    <form>
      <selection id="left">
        [% FOREACH rev IN out.revisions %]
          <option id="[% rev.revision %]">[% rev.revision %]</option>
        [% END %]
      </selection>
      <selection id="right">
        [% FOREACH rev IN out.revisions %]
          <option id="[% rev.revision %]">[% rev.revision %]</option>
        [% END %]
      </selection>
      <submit id="action"><caption>Diff</caption></submit>
      <submit id="action"><caption>3-Way Diff</caption></submit>
    </form>
  [% END %]
  </head>
  <content>
    <link url="./">Folder Listing</link>
    <table id="listing">
      <tgroup>
      <thead sort="[% out.listing.sort %]" order="[% out.listing.sortorder %]">
        <column width="10%">Tags</column>
        <column width="10%">Revision</column>
        <column width="10%">Modifier</column>
        <column width="10%">Modification Date</column>
        <column width="20%">Options</column>
        <column width="20%">Log</column>
      </thead>
      <!-- row>
        <column><link url="./">./</link></column>
        <column/>
        <column/>
        <column/>
      </row -->
      [% FOREACH rev IN out.revisions %]
        <row>
          <column>
            <!-- tags -->
          </column>
          <column>[% rev.revision %]</column>
          <column>[% rev.user.type %]:[% rev.user.id %]</column>
          <column>[% rev.modify_timestamp %]</column>
          <column>
            <form>
              [% IF out.path.viewable %]
                <submit id="action.view"><default>[% rev.revision | html %]</default>
                  <caption>
                    <graphic fileref="/images/icons/file-manager/view_text.png">
                      <caption>View</caption>
                    </graphic>
                  </caption>
                </submit>
              [% END %]
              [% IF out.path.modifiable %]
                <submit id="action.edit"><default>[% rev.revision | html %]</default>
                  <caption>
                    <graphic fileref="/images/icons/file-manager/edit.png">
                      <caption>Edit</caption>
                    </graphic>
                  </caption>
                </submit>
              [% END %]
              [% IF out.path.executable == rev.revision %]
                <submit id="action.exec"><default>[% rev.revision | html %]</default>
                  <caption>
                    <graphic fileref="/images/icons/file-manager/exec.png">
                      <caption>Test</caption>
                    </graphic>
                  </caption>
                </submit>
              [% END %]
            </form>
          </column>
          <column>[% rev.log | html %]</column>
        </row>
      [% END %]
      </tgroup>
    </table>
  </content>
</container>
EOXML

        "$base/diff" => <<'EOXML',
<container>
  <title>Diff - [% out.path %]: [% out.left %] and [% out.right %]</title>
  <content>
    <para><link url="">Revision list</link></para>
    <table>
      <tgroup>
        <thead>
          <column>[% out.left %]</column>
          <column>[% out.right %]</column>
        </thead>
        [% FOREACH row IN out.diff %]
          <row>
            [% SET class.left = "diff-unchanged" %]
            [% SET class.right= "diff-unchanged" %]
            [% IF row.0 == 'c' %]
                [% SET class.left ="diff-changed" %]
                [% SET class.right="diff-changed" %]
            [% ELSIF row.0 == '+' %]
                [% SET class.right="diff-right" %]
            [% ELSIF row.0 == '-' %]
                [% SET class.left="diff-left" %]
            [% END %]
            <column class="[% class.left %]">
              [%- IF row.1 == '' %]<nbsp/>[% ELSE %][% row.1  | html | replace('  ','<nbsp/> ') %][%END -%]
            </column>
            <column class="[% class.right %]">
              [%- IF row.2 == '' %]<nbsp/>[% ELSE %][% row.2  | html | replace('  ','<nbsp/> ') %][%END -%]
            </column>
          </row>
        [% END %]
      </tgroup>
    </table>
  </content>
</container>
EOXML

        "$base/three_diff" => <<'EOXML',
<container>
  <title>3-Way Diff - [% out.path %]: [% out.left %] and [% out.right %]</title>
  <content>
    <para><link url="">Revision list</link></para>
    <table>
      <tgroup>
        <thead>
          <column>[% out.left %]</column>
          <column>[% out.middle %]</column>
          <column>[% out.right %]</column>
        </thead>
        [% FOREACH row IN out.diff %]
          [% SET class.left  ="diff-unchanged" %]
          [% SET class.middle="diff-unchanged" %]
          [% SET class.right ="diff-unchanged" %]
          [% IF row.0 == 'c' %]
            [% SET class.left  ="diff-conflict" %]
            [% SET class.middle="diff-conflict" %]
            [% SET class.right ="diff-conflict" %]
          [% ELSIF row.0 == 'l' %]
            [% SET class.left  ="diff-different" %]
          [% ELSIF row.0 == 'r' %]
            [% SET class.right ="diff-different" %]
          [% ELSIF row.0 == 'o' %]
            [% SET class.middle="diff-different" %]
          [% END %]
          <row>
            <column class="[% class.left %]">
              [%- IF row.2 == '' %]<nbsp/>[% ELSE %][% row.2  | html | replace('  ','<nbsp/> ') %][%END -%]
            </column>
            <column class="[% class.middle %]">
              [%- IF row.1 == '' %]<nbsp/>[% ELSE %][% row.1  | html | replace('  ','<nbsp/> ') %][%END -%]
            </column>
            <column class="[% class.right %]">
              [%- IF row.3 == '' %]<nbsp/>[% ELSE %][% row.3  | html | replace('  ','<nbsp/> ') %][%END -%]
            </column>
          </row>
        [% END %]
      </tgroup>
    </table>
  </content>
</container>
EOXML

    },

    xsm => {
###
### User Management
###

        "$secure/login" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:auth="http://ns.gestinanna.org/auth"
  xmlns:pof="http://ns.gestinanna.org/pof"
  xmlns:xml-simple="http://ns.gestinanna.org/xml-simple"
>
  <alias id="_begin" state="logged_out"/>

  <state id="logged_out">
    <filter id="trim"/>
    <transition state="logged_in">
      <variable id="username"/>
      <variable id="password">
        <constraint id="auth:authentic">
          <param id="password"/>
          <param id="username"/>
        </constraint>
      </variable>
      <variable id="action.login"/>

      <script>
        <value-of select="
          auth:set-actor(
            pof:new(
              'actor',
              pof:new(
                'username',
                /username)/user-id
            )
          )
        "/>
      </script>
    </transition>
  </state>

  <state id="logged_in">
    <filter id="trim"/>
    <transition state="logged_out">
      <variable id="action.logout"/>
      <script>
        <value name="/username" select="null()"/>
        <value name="/password" select="null()"/>
        <value-of select="auth:set-actor(null())"/>
      </script>
    </transition>
  </state>
</statemachine>
EOXML

        "$secure/user/create" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:auth="http://ns.gestinanna.org/auth"
  xmlns:smtp="http://ns.gestinanna.org/smtp"
  xmlns:digest="http://ns.gestinanna.org/digest"
  xmlns:pof="http://ns.gestinanna.org/pof"
  xmlns:content-provider="http://ns.gestinanna.org/content-provider"
  xmlns:xml-simple="http://ns.gestinanna.org/xml-simple"
>
  <alias id="_begin" state="step_1"/>

  <state id="step_1">
    <transition state="confirm">
      <filter id="trim"/>

      <variable id="username">
        <filter id="lc"/>
        <constraint id="auth:username"/>
      </variable>
      <variable id="email">
        <constraint id="email"/>
      </variable>
      <variable id="password2">
        <constraint id="equal">
          <param id="password1"/>
          <param id="password2"/>
        </constraint>
        <constraint id="auth:password"/>
      </variable>
      <variable id="password1"/>
    </transition>
  </state>

  <state id="select_username">
    <transition state="confirm">
      <filter id="trim"/>

      <variable id="username">
        <filter id="lc"/>
        <constraint id="auth:username"/>
      </variable>
    </transition>

    <transition state="step_1">
      <filter id="lc"/>
      <variable id="action">
        <constraint equal="start over"/>
      </variable>
    </transition>
  </state>

  <state id="confirm">
    <filter id="trim"/>
    <filter id="lc"/>

    <script when="pre">
      <!-- lock:if type="username" id="{{/username}}"/ -->
        <variable name="username" select="pof:new('username', /username)"/>
        <assert test="not($username/is-live)" state="select_username" />
      <!-- /lock:if -->
    </script>


    <transition state="step_1">
      <variable id="action">
        <constraint equal="prev"/>
      </variable>
    </transition>

    <transition state="finish">
      <variable id="action">
        <constraint equal="finish"/>
      </variable>

      <script>
        <!-- lock:if type="username" id="{{/username}}"/ -->
          <variable name="username" select="pof:new('username', /username)"/>
          <assert test="not($username/is-live)" state="select_username" />
          <variable name="user" select="pof:new('user', null())"/>
          <value name="$user/password" select="auth:encode-password(/password1)"/>
          <value name="$user/email" select="/email"/>
          <choose>
            <when test="$user/method::save">
              <value name="$username/user_id" select="$user/object_id"/>
              <value name="/password_check" select="digest:md5_hex(concat(digest:md5_hex(/username), /password))"/>
              <value name="$username/password_check" select="/password_check"/>
              <if test="not($username/method::save)">
                <value name="context::messages/error" select="'Unable to create account.'"/>
                <goto state="step_1"/>
              </if>
            </when>
            <otherwise>
              <value name="context::messages/error" select="'Unable to create account.'"/>
              <goto state="step_1"/>
            </otherwise>
          </choose>
        <!-- /lock:if -->
  

        <!-- now send e-mail -->
        <smtp:send-mail>
          <smtp:from select="'jgsmith@tamu.edu'"/>
          <smtp:to select="/email"/>
          <smtp:subject select="'Welcome to the test system'"/>
          <smtp:reply-to select="'jgsmith@tamu.edu'"/>
          <smtp:body>
            <content-provider:process type="view" id="email">
              <association>
                <value name="password_check" select="/password_check"/>
                <value name="email" select="/email"/>
              </association>
            </content-provider:process>
          </smtp:body>
        </smtp:send-mail>
      </script>
    </transition>
  </state>

</statemachine>
EOXML

        "$secure/user/confirm" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:auth="http://ns.gestinanna.org/auth"
  xmlns:smtp="http://ns.gestinanna.org/smtp"
  xmlns:digest="http://ns.gestinanna.org/digest"
  xmlns:pof="http://ns.gestinanna.org/pof"
  xmlns:content-provider="http://ns.gestinanna.org/content-provider"
  xmlns:xml-simple="http://ns.gestinanna.org/xml-simple"
> 
  <alias id="_begin" state="activate"/>

  <state id="activate">
    <transition state="finish">
      <filter id="trim"/>
      <variable id="username">
        <filter id="lc"/>
        <constraint id="auth:username"/>
      </variable>
      <variable id="email">
        <constraint id="email"/>
      </variable>
      <script>
        <variable name="username" select="pof:new('username', /username)"/>
        <assert test="$username/is-live" state="activate"/>
        <assert test="concat('/', $username/password_check) = context::/in/sys/path_info" state="activate"/>
        <variable name="user" select="pof:new('user', $username/user_id)"/>
        <assert test="$user/is-live" state="activate"/>
        <assert test="$user/email = /email" state="activate"/>
        <assert test="not($username/activated)" state="set_password"/>
        <!-- mark the account as confirmed -->
        <value name="$username/activated" select="gmt-now()"/>
        <if test="not($username/method::save)">
          <value name="context::/messages/error" select="'Unable to finish account creation.'"/>
          <goto state="activate"/>
        </if>
      </script>
    </transition>
  </state>

  <state id="set_password">
    <transition state="finish_password">
      <filter id="trim"/>
      <variable id="password1">
        <constraint id="auth:password"/>
        <constraint id="equal">
          <param id="password1"/>
          <param id="password2"/>
        </constraint>
      </variable>
      <variable id="password2"/>


      <script>
        <variable name="username" select="pof:new('username', /username)"/>
        <variable name="user" select="pof:new('user', $username/user_id)"/>
        <value name="$user/password" select="auth:encode-password(/password1)"/>
        <if test="not($user/method::save)">
          <value name="context::/messages/error" select="'Unable to change password.'"/>
          <goto state="activate"/>
        </if>
      </script>
    </transition>
  </state>
</statemachine>
EOXML

###
### Site Configuration
###
        "$secure/configure" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:pof="http://ns.gestinanna.org/pof"
  xmlns:xml-simple="http://ns.gestinanna.org/xml-simple"
> 
  <alias id="_begin" state="site_list"/>

  <script when="pre">
    <variable name="site-id-iterator">
      <pof:find type="site"> <!-- getting all of them -->
        <pof:exists attribute="site"/>
      </pof:find>
    </variable>
    <for-each select="$site-id-iterator/method::get-all-ids/*">
      <variable name="site" select="pof:new('site', .)"/>
      <variable name="number" select="$site/site"/>
      <value name="/sites/$number" select="$site/name"/>
    </for-each>
  </script>
        
  <state id="site_list">
    <filter id="trim"/>
    <filter id="lc"/>
  
    <script when="pre">
      <variable name="site-id-iterator">
        <pof:find type="site"> <!-- getting all of them -->
          <pof:exists attribute="site"/>
        </pof:find>
      </variable>
      <for-each select="$site-id-iterator/method::get-all-ids/*">
        <variable name="site" select="pof:new('site', .)"/>
        <variable name="number" select="$site/site"/>
        <value name="/sites/$number" select="$site/name"/>
      </for-each>
    </script>
      
    <transition state="create_site">  
      <variable id="action.add"/>
      
      <script>
        <value name="/siteinfo/site" select="null()"/>
        <goto state="edit_site"/>
      </script>  
    </transition>

    <transition state="clone_site">
      <variable id="action.add"/>
      <variable id="site">
        <filter id="integer"/>
      </variable>

      <script>
        <!-- create a blank config or copy an existing one -->
        <variable name="site" select="pof:new('site', /site)"/>
        <value name="/siteinfo/name" select="''"/>
        <value name="/siteinfo/site" select="null()"/>
        <value name="/siteinfo/config">
          <xml-simple:parse select="$site/configuration"
            content-key="-content"
            force-array="content-provider|data-provider|tag-path"
            normalize-space="2"
          >
            <xml-simple:key-attr element="content-provider" attribute="type"/>
            <xml-simple:key-attr element="data-provider" attribute="type"/>
          </xml-simple:parse>
        </value>
        <!-- force <data-provider/> and <content-provider/> sections into lists 
             not sure that XML::Simple will do it right -->
        <value name="/siteinfo/config/data-provider" select="list(/siteinfo/config/data-provider)"/>
        <value name="/siteinfo/config/content-provider" select="list(/siteinfo/config/content-provider)"/>
        <goto state="edit_site"/>
      </script>

    </transition>

    <transition state="delete_site">

      <variable id="action.delete"/>
      <variable id="site">
        <filter id="integer"/>
      </variable>

      <script>
        <set-namespace name="config" select="gst:config()"/>
        <!-- make sure we aren't trying to delete the configuration for the site being used -->
        <for-each select="/child-or-self::site">
          <assert test=". != config::/site" state="site_list">
            <value name="/messages/error" select="'Cannot delete the site you&quot;re using.'"/>
          </assert>
        </for-each>
        <goto state="site_list"/> <!-- or go to another page to confirm the deletions -->
      </script>

    </transition>
    <transition state="edit_site">

      <variable id="action.edit"/>
      <variable id="site" dependence="OPTIONAL">
        <filter id="integer"/>
        <!-- constraint count="1"/> <need to see how Data::FormValidator handles this -->
      </variable>

      <script>
        <variable name="site">
          <choose>
            <when test="/site">
              <value-of select="pof:new('site', /site)"/>
            </when>
            <otherwise>
              <!-- load config for current site -->
            </otherwise>
          </choose>
        </variable>
        <value name="/siteinfo/name" select="$site/name"/>
        <value name="/siteinfo/site" select="$site/site"/>
        <value name="/siteinfo/config">
          <xml-simple:parse select="$site/configuration"
            content-key="-content"
            force-array="content-provider|data-provider|tag-path"
            normalize-space="2"
          >
            <xml-simple:key-attr element="content-provider" attribute="type"/>
            <xml-simple:key-attr element="data-provider" attribute="type"/>
          </xml-simple:parse>
        </value>
      </script>

    </transition>
  </state>

  <state id="edit_site">

    <filter id="trim"/>

    <transition state="create_dp">
      <variable id="data-provider.action.add"/>
      <script>
        <value name="/dpinfo/type" select="''"/>
        <goto state="edit_dp"/>
      </script>
    </transition>

    <transition state="clone_dp">
      <variable id="data-provider.action.add"/>
      <variable id="data-provider.selection"/>
      <script>
        <variable name="dp" select="/data-provider/selection"/>
        <value name="/dpinfo" select="clone(/siteinfo/config/data-provider/{$dp})"/>
        <value name="/dpinfo/type" select="''"/>
        <goto state="edit_dp"/>
      </script>
    </transition>

    <transition state="edit_dp">
      <variable id="data-provider.action.edit"/>
      <variable id="data-provider.selection"/>
      <script>
        <variable name="dp" select="/data-provider/selection"/>

        <value name="/dpinfo" select="clone(/siteinfo/config/data-provider/{$dp})"/>

        <value name="/dpinfo/type" select="$dp"/>

        <variable name="schema" select="gst:alzabo-schema()"/>

        <variable name="tables" select="gst:alzabo-schema()/tables/name"/>

        <value name="/dpinfomisc/alzabo/repositories" select="
          $tables/*[
                (gst:alzabo-schema()/has-table(concat(., '_Tag')))
            and (gst:alzabo-schema()/has-table(concat(., '_Description')))
          ] "
        />
        <value name="/dpinfomisc/alzabo/tables" select="
          $tables/*[
            not( ends-with(., '_Tag')
                 or ends-with(., '_Description')
                 or gst:alzabo-schema()/has-table(concat(., '_Tag'))
                 or gst:alzabo-schema()/has-table(concat(., '_Description'))
            )
          ]"
        />

        <value name="/dpinfomisc/ldap/branches" select="gst:ldap-rootdse()/get-value('namingContexts')"/>
      </script>
    </transition>

    <transition state="delete_dp">
      <variable id="data-provider.action.delete"/>
      <variable id="data-provider.selection"/>
    </transition>

    <transition state="confirm_edits">

      <variable id="action.done"/>

      <variable id="name"/>
      <variable id="package"/>
      <variable id="session.cookie.name"/>
      <variable id="session.store.store"/>
      <variable id="session.store.lock"/>
      <variable id="session.store.generate"/>
      <variable id="session.store.serialize"/>

      <script>
        <if test="defined(/name)">
          <value name="/siteinfo/name"
                        select="/name"/>
        </if>
        <if test="defined(/package)">
          <value name="/siteinfo/config/package"
                               select="/package"/>
        </if>
        <if test="defined(/session/cookie/name)">
          <value name="/siteinfo/config/session/cookie/name"
                               select="/session/cookie/name"/>
        </if>
        <if test="defined(/session/store/store)">
          <value name="/siteinfo/config/session/store/store"
                               select="/session/store/store"/>
        </if>
        <if test="defined(/session/store/lock)">
          <value name="/siteinfo/config/session/store/lock"
                               select="/session/store/lock"/>
        </if>
        <if test="defined(/session/store/generate)">
          <value name="/siteinfo/config/session/store/generate"
                               select="/session/store/generate"/>
        </if>
        <if test="defined(/session/store/serialize)">
          <value name="/siteinfo/config/session/store/serialize"
                               select="/session/store/serialize"/>
        </if>
        <value name="/siteinfo/configxml">
          <xml-simple:deparse select="/siteinfo/config"
            root-name="configuration"
            content-key="-content"
            force-array="content-provider|data-provider|tag-path"
            normalize-space="0"
          >
            <xml-simple:key-attr element="content-provider" attribute="type"/>
            <xml-simple:key-attr element="data-provider" attribute="type"/>
          </xml-simple:deparse>
        </value>
      </script>

    </transition>
  </state>

  <state id="clone_site">
    <filter id="trim"/>
    <transition state="site_list">
      <variable id="action">
        <filter id="lc"/>
        <constraint equal="cancel"/>
      </variable>
    </transition>

    <transition state="edit_site">
      <variable id="action">
        <filter id="lc"/>
        <constraint equal="continue"/>
      </variable>
      <variable id="name"/>

      <script>
        <value name="/siteinfo/name" select="/name"/>
        <value name="/siteinfo/site" select="null()"/>
      </script>
    </transition>
  </state>
  <state id="confirm_edits">
    <filter id="trim"/>
    <filter id="lc"/>

    <transition state="site_list_save">
      <variable id="action">
        <constraint equal="confirm"/>
      </variable>

      <script>
        <variable name="site" select="pof:new('site', /siteinfo/site)"/>
        <value name="$site/configuration" select="/siteinfo/configxml"/>
        <value name="$site/name" select="/siteinfo/name"/>
        <assert test="$site/method::save" state="confirm_edits">
          <value name="/messages/error" select="'Unable to save configuration.'"/>
        </assert>
        <goto state="site_list"/>
      </script>
    </transition>

    <transition state="site_list">
      <variable id="action">
        <constraint equal="drop changes"/>
      </variable>
    </transition>

    <transition state="edit_site">
      <variable id="action">
        <constraint equal="edit"/>
      </variable>
    </transition>
  </state>
  <state id="edit_dp">
    <filter id="trim"/>
      
    <transition state="edit_site">
      <variable id="action">
        <filter id="lc"/>
        <constraint equal="cancel"/>
      </variable>
    </transition>
      
    <transition state="edit_site_perl">

      <variable id="action">
        <filter id="lc"/>
        <constraint equal="accept"/>
      </variable>
      <variable id="type"/>
      <variable id="implementation.value">
        <constraint equal=""/>
      </variable>
      <variable id="implementation.class"/>
      
      <script>
        <value name="/dpinfo/type" select="/type"/>
        <value name="/dpinfo/data-type" select="null()"/>
        <goto state="edit_site"/>
      </script>
    </transition>
        
    <transition state="edit_site_alzabo">
        
      <variable id="action">
        <filter id="lc"/>
        <constraint equal="accept"/>
      </variable>
      <variable id="type"/>
      <variable id="implementation.value">
        <constraint equal="alzabo"/>
      </variable>
      <variable id="implementation.alzabo.table"/>

      <script>
        <value name="/dpinfo/type" select="/type"/>
        <value name="/dpinfo/data-type" select="'alzabo'"/>
        <value name="/dpinfo/alzabo/table" select="/implementation/alzabo/table"/>
        <goto state="edit_site"/>
      </script>
    </transition>
    <transition state="edit_site_repository">

      <variable id="action">
        <filter id="lc"/>
        <constraint equal="accept"/>
      </variable>
      <variable id="type"/>
      <variable id="implementation.value">
        <constraint equal="repository"/>
      </variable>
      <variable id="implementation.repository.repository"/>

      <script>
        <value name="/dpinfo/type" select="/type"/>
        <value name="/dpinfo/data-type" select="'repository'"/>
        <value name="/dpinfo/repository/repository" select="/implementation/repository/repository"/>
        <goto state="edit_site"/>
      </script>
    </transition>

    <transition state="edit_site_ldap">

      <variable id="action">
        <filter id="lc"/>
        <constraint equal="accept"/>
      </variable>
      <variable id="type"/>
      <variable id="implementation.value">
        <constraint equal="ldap"/>
      </variable>
      <variable id="implementation.ldap.branch"/>
      <variable id="implementation.ldap.uid"/>

      <script>
        <value name="/dpinfo/type" select="/type"/>
        <value name="/dpinfo/data-type" select="'ldap'"/>
        <value name="/dpinfo/ldap/branch" select="/implementation/ldap/branch"/>
        <value name="/dpinfo/ldap/uid" select="/implementation/ldap/uid"/>
        <goto state="edit_site"/>
      </script>
    </transition>

  </state>
</statemachine>
EOXML

###
### File Manager
###
        "$base/manage/folder" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:pof="http://ns.gestinanna.org/pof"
>
  <state id="create">
    <transition state="save">
      <filter id="trim"/>

      <variable id="action.finish"/>
      <variable id="filename">
        <constraint id="gst:filename"/>
      </variable>
      <variable id="description" dependence="OPTIONAL"/>
      <script>
        <variable name="ob">
          <pof:new type='folder'>
            <with-param name="object_id" select="concat(context::/in/sys/path_info, /filename)"/>
          </pof:new>
        </variable>
        <log level="warn"><value-of select="$ob"/></log>
        <assert test="not($ob/is-live)" state="create">
          <value name="/messages/error" select="'A folder already exists by that name.'"/>
        </assert>
        <value name="$ob/description" select="/description"/>
        <assert test="$ob/method::save()" state="create">
          <value name="/messages/error" select="'Unable to create folder.'"/>
        </assert>
      </script>
    </transition>

    <transition state="discard">
      <variable id="action.discard"/>
    </transition>
  </state>
</statemachine>
EOXML

        "$base/manage/document" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:pof="http://ns.gestinanna.org/pof"
>
  <script when="pre">
    <value name="/type" select="'document'"/>
  </script>

  <state id="create">
    <script when="pre">
      <variable name="ob">
        <pof:new type="document">
          <with-param name="object_id" select="concat('/sys/file-manager/manage/templates/', /type)"/>
        </pof:new>
      </variable>
      <value name="/data" select="$ob/data"/>
    </script>

    <transition state="create_edit">
      <filter id="trim"/>

      <variable id="action.next"/>
      <variable id="filename">
        <constraint id="gst:filename"/>
      </variable>
      <variable id="description" dependence="OPTIONAL"/>
      <script>
        <variable name="ob" select="pof:new(/type, concat(context::/in/sys/path_info, /filename))"/>
        <assert test="not(ob/method::is-live)" state="start">
          <value name="/messages/_error" select="'An object of this type already exists by that name.'"/>
        </assert>
      </script>
    </transition>

    <transition state="discard">
      <variable id="action.discard"/>
    </transition>
  </state>

  <state id="create_edit">
    <transition state="save">
      <variable id="action.save"/>
      <variable id="data"/>
      <script>
        <variable name="ob" select="pof:new(/type, concat(context::/in/sys/path_info, /filename))"/>
        <assert test="not(ob/method::is-live)" state="start">
          <value name="/messages/_error" select="'An object of this type already exists by that name.'"/>
        </assert>
        <value name="$ob/data" select="/data"/>
        <value name="$ob/log" select="'Initial creation'"/>
        <assert test="$ob/method::save" state="create_edit">
          <value name="/messages/_error" select="'Unable to save object.'"/>
        </assert>
      </script>
    </transition>

    <transition state="discard">
      <variable id="action.discard"/>
    </transition>
  </state>

  <state id="edit">
    <script when="pre">
      <if test="not(/data)">
        <variable name="ob">
          <pof:new type="{/path/type}">
            <with-param name="object_id" select="/path/name"/>
            <with-param name="revision" select="/revision"/>
          </pof:new>
        </variable>
        <value name="/data" select="$ob/data"/>
      </if>
    </script>

    <transition state="save">
      <variable id="action.save"/>
      <variable id="data"/>
      <variable id="log"/>
      <script>
        <variable name="ob">
          <pof:new type="{/path/type}">
            <with-param name="object_id" select="/path/name"/>
            <with-param name="revision" select="/revision"/>
          </pof:new>
        </variable>
        <value name="$ob/data" select="/data"/>
        <value name="$ob/log" select="/log"/>
        <assert test="$ob/method::save()" state="edit">
          <value name="/messages/_error" select="'Unable to save object.'"/>
        </assert>
      </script>
    </transition>

    <transition state="discard">
      <variable id="action.discard"/>
    </transition>
  </state>

  <state id="view">
    <script when="pre">
      <if test="not(/data)">
        <variable name="ob">
          <pof:new type="{/path/type}">
            <with-param name="object_id" select="/path/name"/>
            <with-param name="revision" select="/revision"/>
          </pof:new>
        </variable>
        <value name="/data" select="$ob/data"/>
      </if>
    </script>
    <transition state="discard">
      <variable id="action.discard"/>
    </transition>
  </state>
</statemachine>
EOXML

        "$base/manage/view" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
>
  <inherit name="/sys/file-manager/manage/document"/>

  <script when="pre">
    <value name="/type" select="'view'"/>
  </script>
</statemachine>
EOXML

        "$base/manage/xslt" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
>
  <inherit name="/sys/file-manager/manage/document"/>

  <script when="pre">
    <value name="/type" select="'xslt'"/>
  </script>
</statemachine>
EOXML

        "$base/manage/portal" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
>
  <inherit name="/sys/file-manager/manage/document"/>

  <script when="pre">
    <value name="/type" select="'portal'"/>
  </script>
</statemachine>
EOXML

        "$base/manage/xsm" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
>
  <inherit name="/sys/file-manager/manage/document"/>

  <state id="create">
    <script when="pre"/>
    <transition state="do_create">
      <filter id="trim"/>

      <variable id="action.next"/>
      <variable id="filename">
        <constraint id="gst:filename"/>
      </variable>
      <variable id="description" dependence="OPTIONAL"/>
      <variable id="type">
        <filter id="lc"/>
      </variable>

      <script>
        <goto state-machine="{concat('/sys/file-manager/manage/xsm/', /type)}" next-state="return">
          <with-param name="filename" select="/filename"/>
          <with-param name="description" select="/description"/>
        </goto>
      </script>
    </transition>

    <transition state="discard">
      <variable id="action.discard"/>
    </transition>
  </state>
</statemachine>
EOXML

        "$base/manage/xsm/plain" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
>
  <inherit name="/sys/file-manager/manage/document"/>

  <script when="pre" super="end">
    <value name="/type" select="'xsm'"/>
  </script>
</statemachine>
EOXML

        # empty base class to catch default templates for buttons and such
        "/sys/xsm/wizard" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
>
  <state id="finish">
    <!-- allows basic testing of data collection -->

    <transition state="_begin">
        <variable id="action.discard"/>
    </transition>

    <transition state="end">
        <variable id="action.done"/>
    </transition>

  </state>
</statemachine>
EOXML

        "$base/manage/xsm/wizard" => <<'EOXML',
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:content-provider="http://ns.gestinanna.org/content-provider"
  xmlns:pof="http://ns.gestinanna.org/pof"
>
  <alias id="_begin" state="steps"/>

  <state id="steps">
    <filter id="trim"/>

    <transition state="add_step">
      <group id="action" some='1'>
        <variable id="add"/>
        <variable id="add.before"/>
        <variable id="add.after"/>
      </group>
      <variable id="steps" dependence="OPTIONAL"/>
        <!-- constraint count-max="1"/>
      </variable -->
      <variable id="filters" dependence="OPTIONAL"/>
      <variable id="title" dependence="OPTIONAL"/>
      <script>
        <choose>
          <when test="not(defined(/steps))">
            <value name="/position/step" select="-1"/>
            <value name="/placement/step" select="'end'"/>
          </when>
          <when test="defined(/action/add/after)">
            <assert test="1 >= count(list(/steps))" state="steps"/>
            <value name="/position/step" select="/steps + 1"/>
            <value name="/placement/step" select="'insert'"/>
          </when>
          <when test="defined(/action/add/before)">
            <assert test="1 >= count(list(/steps))" state="steps"/>
            <value name="/position/step" select="/steps - 1"/>
            <value name="/placement/step" select="'insert'"/>
          </when>
          <otherwise>
            <value name="/position/step" select="-1"/>
            <value name="/placement/step" select="end"/>
          </otherwise>
        </choose>
        <value name="/step"><association/></value>
        <goto state="edit_step"/>
      </script>
    </transition>

    <transition state="delete_step">
      <variable id="action.delete"/>
      <variable id="steps"/>
        <!-- constraint count-min="1"/>
      </variable -->
      <variable id="filters" dependence="OPTIONAL"/>
      <variable id="title" dependence="OPTIONAL"/>

      <script>
        <assert test="count(list(/steps)) >= 1" state="steps"/>
        <for-each select="/steps/*">
          <sort select="1000 - ."/> <!-- make sure we can numerically sort in reverse order -->
          <value name="/data/steps" select="splice(list(/data/steps)/*, ., 1)"/>
        </for-each>
        <goto state="steps"/>
      </script>
    </transition>

    <transition state="edit_step">
      <variable id="action.edit"/>
      <variable id="steps"/>
      <variable id="filters" dependence="OPTIONAL"/>
      <variable id="title" dependence="OPTIONAL"/>
      <script>
        <value name="/position/step" select="/steps"/>
        <value name="/placement/step" select="'inplace'"/>
        <variable name="id" select="/steps"/>

        <value name="/step" select="clone(/data/steps/{$id})"/>
      </script>
    </transition>

    <transition state="discard">
      <variable id="action.discard"/>
    </transition>

    <transition state="save">
      <variable id="action.save"/>
      <variable id="filters" dependence="OPTIONAL"/>
      <variable id="title" dependence="OPTIONAL"/>
      <script>
        <variable name="base" select="concat(context::/in/sys/path_info, /filename)"/>
        <variable name="xsm-ob" select="pof:new('xsm', $base)"/>
        <value name="$xsm-ob/data">
          <content-provider:process type="view" id="xsm">
            <association>
              <value name="steps" select="/data/steps"/>
            </association>
          </content-provider:process>
        </value>
        <value name="$xsm-ob/log" select="'Initial creation'"/>
        <assert test="$xsm-ob/method::save" state="steps">
          <value name="/messages/error" select="'Unable to create XSM object.'"/>
        </assert>
        <!-- now go through and create the views -->
        <for-each select="/data/steps/*">
          <variable name="view">
            <choose>
              <when test="defined(./view)"><value-of select="./view"/></when>
              <otherwise><value-of select="concat('step_', position()+1)"/></otherwise>
            </choose>
          </variable>
          <variable name="view-ob" select="pof:new('view', concat($base, '/', $view))"/>
          <value name="$view-ob/data">
            <content-provider:process type="view" id="view">
              <association>
                <value name="title" select="/title"/>
                <value name="step" select="position()"/>
                <value name="steps" select="last()"/>
                <value name="variables" select="./variables"/>
              </association>
            </content-provider:process>
          </value>
          <value name="$view-ob/log" select="'Initial creation'"/>
          <assert test="$view-ob/method::save" state="steps">
            <value name="/messages/error" select="concat('Unable to create object for ', $view, '.')"/>
          </assert>
        </for-each>
      </script>
    </transition>
  </state>

  <state id="edit_step">
    <transition state="save_step">
      <variable id="step.view" dependence="OPTIONAL"/>
      <variable id="step.filters" dependence="OPTIONAL"/>
      <variable id="action.save"/>

      <script>
        <!-- we want to put the /step data into the right place in /steps -->
        <choose>
          <when test="/position/step = -1"> <!-- adding to end -->
            <value name="/data/steps" select="list(/data/steps | /step)"/>
          </when>
          <when test="/placement/step = 'insert'">
            <value name="/data/steps" select="splice(list(/data/steps)/*, /position/step, 0, /step)"/>
          </when>
          <when test="/placement/step = 'inplace'">
            <value name="/data/steps" select="splice(list(/data/steps)/*, /position/step, 1, /step)"/>
          </when>
        </choose>
        <value name="/step" select="null()"/>
        <goto state="steps"/>
      </script>
    </transition>

    <transition state="steps">
      <variable id="action.discard"/>
      <script>
        <value name="/step" select="null()"/>
        <value name="/position/step" select="null()"/>
        <value name="/placement/step" select="null()"/>
      </script>
    </transition>

    <transition state="add_variable">
      <variable id="action.add"/>
      <variable id="step.filters" dependence="OPTIONAL"/>
      <script>
        <value name="/variable"><association/></value>
        <value name="/position/variable" select="-1"/>
        <goto state="edit_variable"/>
      </script>
    </transition>

    <transition state="delete_variable">
      <variable id="variables"/>
        <!-- constraint count-min="1"/>
      </variable -->
      <variable id="action.delete"/>
      <variable id="step.filters" dependence="OPTIONAL"/>

      <script>
        <assert test="count(list(/variables)) >= 1" state="edit_step"/>
        <for-each select="list(/variables)/*">
          <sort select="999 - ."/>
          <value name="/step/variables" select="splice(list(/step/variables)/*, ., 1)"/>
        </for-each>
        <goto state="edit_step"/>
      </script>
    </transition>

    <transition state="edit_variable">
      <variable id="action.edit"/>
      <variable id="variables"/>
        <!-- constraint count="1"/>
      </variable -->
      <variable id="step.filters" dependence="OPTIONAL"/>
      <script>
        <assert test="count(list(/variables)) = 1" state="edit_step"/>
        <variable name="id" select="/variables"/>
        <value name="/variable" select="clone(/step/variables/{$id})"/>
        <value name="/position/variable" select="/variables"/>
      </script>
    </transition>
  </state>

  <state id="edit_variable">
    <transition state="save_variable">
      <variable id="action.save"/>
      <group id="variable">
        <variable id="id"/>
        <variable id="caption" dependence="OPTIONAL"/>
        <variable id="dependence"/>
        <variable id="type.value"/>
        <variable id="type.selection.count" dependence="OPTIONAL"/>
        <variable id="type.selection.options" dependence="OPTIONAL">
          <filter id="gst:multiline"/>
        </variable>
        <variable id="filters" dependence="OPTIONAL"/>
        <group id="constraints" dependence="OPTIONAL">
          <variable id="id"/>
          <variable id="min_length"/>
          <variable id="max_length"/>
          <variable id="length"/>
          <variable id="equal"/>
        </group>
      </group>
      <script>
        <choose>
          <when test="/position/variable = -1"> <!-- adding to end -->
            <value name="/step/variables" select="list(list(/step/variables)/* | /variable)"/>
          </when>
          <otherwise>
            <value name="/step/variables" select="splice(list(/step/variables)/*, /position/variable, 1, /variable)"/>
          </otherwise>
        </choose>
        <value name="/variable"><association/></value>
        <goto state="edit_step"/>
      </script>
    </transition> 

    <transition state="edit_step">
      <variable id="action.discard"/>
      <script>
        <value name="/variable" select="null()"/>
        <value name="/position/variable" select="null()"/>
        <value name="/placement/variable" select="null()"/>
      </script>
    </transition>
  </state>
</statemachine>
EOXML

        $base => <<'EOXML'
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:authz="http://ns.gestinanna.org/authz"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:diff="http://ns.gestinanna.org/diff"
  xmlns:pof="http://ns.gestinanna.org/pof"
  xmlns:xml-simple="http://ns.gestinanna.org/xml-simple"
>

  <script when="pre">
    <!-- get a listing of all the repositories -->
    <choose>
      <when test="ends-with(context::/in/sys/path_info, '/')">
        <goto state="file_list"/>
      </when>
      <otherwise>
        <goto state="revision_list"/>
      </otherwise>
    </choose>
  </script>

  <state id="revision_list" save-context="no">
    <script when="pre">
      <!-- get version information for the file -->
      <value name="/path" select="gst:split-path(context::/in/sys/path_info)"/>
      <value name="/path/modifiable" select="authz:has_access(/path/type, /path/name, 'write')"/>
      <value name="/path/viewable" select="authz:has_access(/path/type, /path/name, 'read')"/>
      <if test="/path/type = 'xsm' and /path/viewable and authz:has_access(/path/type, /path/name, 'exec')">
        <value name="/path/executable" select="pof:new(/path/type, /path/name)/revision"/>
      </if>

      <if test="/path/type != '' and /path/name != ''">
        <variable name="file-ob" select="pof:new(/path/type, /path/name)"/>
        <value name="/revisions">
          <list>
            <for-each select="$file-ob/method::revisions()">
              <variable name="ob">
                <pof:new type="{/path/type}">
                  <with-param name="object_id" select="/path/name"/>
                  <with-param name="revision" select="."/>
                </pof:new>
              </variable>
              <association>
                <value name="revision" select="."/>
                <value name="log" select="$ob/log"/>
                <value name="user">
                  <association>
                    <value name="type" select="$ob/user_type"/>
                    <value name="id" select="$ob/user_id"/>
                  </association>
                </value>
                <value name="modify_timestamp" select="$ob/modify_timestamp"/>
              </association>
            </for-each>
          </list>
        </value>
      </if>
    </script>

    <transition state="diff">
      <filter id="trim"/>
      <filter id="lc"/>

      <variable id="action">
        <constraint equal="diff"/>
      </variable>
      <variable id="left"/>
      <variable id="right"/>

      <script>
        <value name="/path" select="context::/in/sys/path_info"/>
        <variable name="type" select="''"/>
        <variable name="file" select="''"/>

        <for-each select="string-length(/path) .. 0">
          <if test="substring(/path, ., 1) = '.' and $type = '' and $file = ''">
            <variable name="type" select="substring(/path, .+1)"/>
            <variable name="file" select="substring(/path, 0, .)"/>
          </if>
        </for-each>
        <value name="/diff" select="null()"/>
        <if test="$type != '' and $file != ''">
          <log level="warn"><value-of select="concat('name=', $file, ', revision=', /left)"/></log>
          <log level="warn"><value-of select="concat('name=', $file, ', revision=', /right)"/></log>
          <variable name="left" select="pof:new($type, concat('name=', $file, ', revision=', /left))/data"/>
          <variable name="right" select="pof:new($type, concat('name=', $file, ', revision=', /right))/data"/>
          <value name="/diff" select="diff:two-way-s($left, $right)"/>
        </if>
      </script>
    </transition>

    <transition state="three_diff">
      <filter id="trim"/>
      <filter id="lc"/>

      <variable id="action">
        <constraint equal="3-way diff"/>
      </variable>
      <variable id="left"/>
      <variable id="right"/>

      <script>
        <value name="/path" select="context::/in/sys/path_info"/>
        <variable name="type" select="''"/>
        <variable name="file" select="''"/>

        <for-each select="string-length(/path) .. 0">
          <if test="substring(/path, ., 1) = '.' and $type = '' and $file = ''">
            <variable name="type" select="substring(/path, .+1)"/>
            <variable name="file" select="substring(/path, 0, .)"/>
          </if>
        </for-each>
        <value name="/diff" select="null()"/>
        <value name="/middle" select="diff:three-way-middle-revision(/left,/right)"/>
        <if test="$type != '' and $file != ''">
          <variable name="left" select="pof:new($type, concat('name=', $file, ', revision=', /left))/data"/>
          <variable name="right" select="pof:new($type, concat('name=', $file, ', revision=', /right))/data"/>
          <variable name="middle" select="pof:new($type, concat('name=', $file, ', revision=', /middle))/data"/>
          <value name="/diff" select="diff:three-way($middle, $left, $right)"/>
        </if>
      </script>
    </transition>

    <!-- need to put in links for editing a revision -->
    <transition state="edit">
      <filter id="trim"/>
      <variable id="action.edit"/>

      <script>
        <assert test="/path/modifiable" state="revision_list"/>
        <goto state-machine="{concat('/sys/file-manager/manage/', /path/type)}" state="edit">
          <with-param name="revision" select="/action/edit"/>
          <with-param name="path" select="/path"/>
        </goto>
      </script>
    </transition>

    <transition state="test">
      <filter id="trim"/>
      <variable id="action.exec"/>

      <script>
        <assert test="/path/executable and /path/type = 'xsm'" state="revision_list"/>
        <goto state-machine="{/path/name}"/>
      </script>
    </transition>

    <transition state="view">
      <filter id="trim"/>
      <variable id="action.view"/>
      <script>
        <assert test="/path/viewable" state="revision_list"/>
        <goto state-machine="{concat('/sys/file-manager/manage/', /path/type)}" state="view">
          <with-param name="revision" select="/action/view"/>
          <with-param name="path" select="/path"/>
        </goto>
      </script>
    </transition>
  </state>

  <state id="file_list">
    <script when="pre">
      <value name="/path/name" select="context::/in/sys/path_info"/>
      <value name="/path/type" select="'folder'"/>
      <variable name="dp-config" select="gst:config()/data-provider"/>

      <if test="authz:has_access('folder', concat(/path/name, '*/'), 'create')">
        <value name="/types/folder" select="'Folder'"/>
      </if>

      <for-each select="
        pof:types()[
          pof:valid-type(concat(., '_tag'))
          and pof:valid-type(concat(., '_repository'))
          and pof:valid-type(concat(., '_description'))
          and authz:has_access(., /path/name, 'read')
        ]"
        as="type"
      >
        <variable name="listing" select="pof:new(concat(.,'_repository'),null())/method::listing(/path/name)"/>

        <if test="authz:has_access(., concat(/path/name, '* | ', /path/name, '*/'), 'create')">
          <value name="/types/$type" select="$dp-config/{$type}/description"/>
        </if>

        <variable name="files">
          <list>
            <for-each select="$listing/files/*[authz:has_access($type, concat(/path/name, .), 'read')]" as="file">
              <variable name="file-ob" select="pof:new($type, concat(/path/name, $file))"/>
              <!-- variable name="lm" select="$file-ob/modify_timestamp"/ -->
              <association>
                <value name="name" select="$file"/>
                <value name="type" select="$type"/>
                <value name="description" select="pof:new(concat($type, '_description'), concat(/path/name, $file))/description"/>
              </association>
            </for-each>
          </list>
        </variable>
 
        <variable name="folders">
          <list>
            <for-each select="$listing/folders/*[authz:has_access($type, concat(/path/name,.,'/'), 'read')]" as="dir">
              <association>
                <value name="name" select="$dir"/>
                <value name="type" select="'folder'"/>
              </association>
            </for-each>
          </list>
        </variable>

        <value name="/files">
          <list>
            <value-of select="unique(/files/*, $files/*, $folders/*)"/>
          </list>
        </value>

      </for-each>
    </script>

    <transition state="create">
      <filter id="trim"/>

      <variable id="action.create"/>
      <variable id="type"/>

      <script>
        <!-- go through available types and call the right state machine -->
        <assert test="authz:has_access(/type, concat(/path/name, '*'), 'create')" state="file_list"/>
        <if test="/type = 'folder'">
          <goto state-machine="/sys/file-manager/manage/folder" state="create"/>
        </if>
        <assert 
          test="
            pof:valid-type(concat(/type, '_tag'))
            and pof:valid-type(concat(/type, '_repository'))
            and pof:valid-type(concat(/type, '_description'))
          "
          state="file_list"
        />
        <goto state-machine="{concat('/sys/file-manager/manage/', /type)}" state="create"/>
      </script>
    </transition>
  </state>
</statemachine>
EOXML
    },

    "xslt" => {
        "/sys/xsm/wizard" => <<'EOXML'
<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wiz="http://ns.gestinanna.org/xsm/xsl/wizard"
  xmlns="http://ns.gestinanna.org/statemachine"
>

<!-- xsl:output indent="yes" / -->

<!-- need to add an alias for _begin => step_1 -->

<xsl:template match="wiz:steps">
  <inherit name="/sys/xsm/wizard"/>
  <alias id="_begin" state="step_1"/>
  <xsl:for-each select="wiz:step">
    <xsl:if test="@alias">
      <alias>
        <xsl:attribute name="id"><xsl:value-of select="@alias"/></xsl:attribute>
        <xsl:attribute name="state"><xsl:value-of select="concat('step_', position())"/></xsl:attribute>
      </alias>
    </xsl:if>
    <state>
      <xsl:attribute name="id">
        <xsl:text>step_</xsl:text>
        <xsl:value-of select="position()"/>
      </xsl:attribute>
      <xsl:if test="@view">
        <xsl:attribute name="view"><xsl:value-of select="@view"/></xsl:attribute>
      </xsl:if>
      <xsl:copy-of xmlns:xsm="http://ns.gestinanna.org/statemachine" select="../xsm:filter"/>
      <xsl:if test="position() > 1">
        <transition>
          <xsl:attribute name="state">
            <xsl:text>step_</xsl:text>
            <xsl:value-of select="position() - 1"/>
          </xsl:attribute>
          <!-- need to copy variables, but make them all optional -->
          <variable id="action.prev"/>
          <xsl:apply-templates select="variable|group|filter" mode="prev"/>
        </transition>
      </xsl:if>
      <transition>
        <xsl:attribute name="state">
          <xsl:choose>
            <xsl:when test="position() = last()">
              <xsl:choose>
                <xsl:when test="@finish"><xsl:value-of select="@finish"/></xsl:when>
                <xsl:otherwise><xsl:text>finish</xsl:text></xsl:otherwise>
              </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>step_</xsl:text>
              <xsl:value-of select="position() + 1"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <!-- need to copy variables -->
        <!-- need to copy any script -->
        <variable id="action.next"/>
        <xsl:apply-templates select="@*|node()"/>
      </transition>
      <xsl:if test="@finish and position() != last()">
        <transition>
          <xsl:attribute name="state">
            <xsl:value-of select="@finish"/>
          </xsl:attribute>
          <variable id="action.finish"/>
          <xsl:apply-templates select="variable | group | filter"/>
        </transition>
      </xsl:if>
      <transition state="discard">
        <variable id="action.discard"/>
      </transition>

      <!-- need transitions to all previous states -->
      <xsl:variable name="my-position" select="position()"/>
      <xsl:for-each select="../wiz:step">
        <xsl:if test="my-position > position()">
          <transition>
            <xsl:attribute name="state">
              <xsl:text>step_</xsl:text>
              <xsl:value-of select="position()"/>
            </xsl:attribute>
            <variable id="action.jump">
              <constraint>
                <xsl:attribute name="equal" select="position()"/>
              </constraint>
            </variable>
            <!-- need to copy variables and make them optional -->
          </transition>
        </xsl:if>
      </xsl:for-each>
      <xsl:apply-templates select="transition" mode="jump" />
    </state>
  </xsl:for-each>
</xsl:template>

<xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
</xsl:template>

<xsl:template match="@* | node()" mode="prev">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="prev"/>
    </xsl:copy>
</xsl:template>

<xsl:template xmlns:xsm="http://ns.gestinanna.org/statemachine" match="xsm:transition" mode="jump">
    <xsm:transition>
      <xsl:apply-templates select="@*|node()"/>
      <xsl:apply-templates select="../xsm:variable | ../xsl:group" mode="prev"/>
      <xsl:apply-templates select="../xsl:filter"/>
    </xsm:transition>
</xsl:template>

<xsl:template xmlns:xsm="http://ns.gestinanna.org/statemachine" match="xsm:variable" mode="prev">
  <xsl:copy>
    <xsl:attribute name="dependence"><xsl:text>OPTIONAL</xsl:text></xsl:attribute>
    <xsl:apply-templates select="@*|node()" mode="prev"/>
  </xsl:copy>
</xsl:template>

<xsl:template xmlns:xsm="http://ns.gestinanna.org/statemachine" match="xsm:script" mode="prev"/>

<xsl:template match="wiz:step"/>
<xsl:template match="wiz:step" mode="prev"/>

<xsl:template match="wiz:step/@finish"/>
<xsl:template match="wiz:step/@finish" mode="prev"/>

</xsl:stylesheet>
EOXML
    },
);

foreach my $type (keys %docs) {
    foreach my $id (keys %{$docs{$type} || {}}) {
        my $doc = $factory -> new($type => object_id => $id);
        $doc -> data($docs{$type}{$id});
        $doc -> log('Import');
        $doc -> save;
    }
}
