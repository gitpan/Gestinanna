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

my $base = '/home/1/gep';

%docs = (
    view => {
        "$base/coding/publication" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content><form>
    <form id="story.publication">
      <caption>Publication Data</caption>
      <textline id="title" required="1"><caption>Title:</caption></textline>
      <textline id="author" required="1"><caption>Author:</caption></textline>
      <selection id="category" required="1">
        <caption>Category:</caption>
        <option id=""><caption/></option>
        <option id="hugo"><caption>Hugo Winner</caption></option>
        <option id="nebula"><caption>Nebula Winner</caption></option>
      </selection>
      <textline id="year" required="1"><caption>Year of Publication/Award:</caption></textline>
    </form>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML
        "$base/coding/story" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.narrative">
        <caption>Narrative</caption>
        <selection id="person">
          <caption>Person</caption>
          <option id=""><caption/></option>
          <option id="3"><caption>Third</caption></option>
          <option id="2"><caption>Second</caption></option>
          <option id="1"><caption>First</caption></option>
        </selection>
        <selection id="tense">
          <caption>Tense</caption>
          <option id=""><caption/></option>
          <option id="past"><caption>Past</caption></option>
          <option id="present"><caption>Present</caption></option>
          <option id="future"><caption>Future</caption></option>
          <option id="mixed"><caption>Mixed</caption></option>
          <option id="other"><caption>Other</caption></option>
        </selection>
      </form>
      <form id="story.setting">
        <caption>Setting</caption>
        <selection id="time">
          <caption>Time</caption>
          <option id=""><caption/></option>
          <option id="present"><caption>Approximate Present</caption></option>
          <option id="future.near"><caption>Near Future</caption></option>
          <option id="past.near"><caption>Near Past</caption></option>
          <option id="future.far"><caption>Far Future</caption></option>
          <option id="past.mid"><caption>Historical Past</caption></option>
          <option id="past.far"><caption>Geological Past</caption></option>
          <option id="outside"><caption>Out of Time</caption></option>
        </selection>
        <selection id="locale">
          <caption>Locale (proximity to North America)</caption>
          <option id=""><caption/></option>
          <option id="3"><caption>0 - 3,000 Miles</caption></option>
          <option id="4"><caption>3,001 - 30,000 Miles</caption></option>
          <option id="5"><caption>30,001 - 300,000 Miles</caption></option>
          <option id="inf"><caption>More than 300,000 Miles</caption></option>
        </selection>
      </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/conclusion" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content><form>
    <form id="story.conclusion">
      <caption>Conclusion</caption>
      <text><para>
Which of the following statements best represents the conclusion of the story?
      </para></text>
      <selection id="ending" count="multiple">
        <caption>
The ending leaves the reader thinking primarily about:
        </caption>
        <option id="existence.main">
            <form>
              <caption>the Main Characters' Individual Existence:</caption>
              <selection>
                <option id=""><caption/></option>
                <option id="positive"><caption>Positive</caption></option>
                <option id="negative"><caption>Negative</caption></option>
                <option id="ambiguous"><caption>Ambiguous</caption></option>
              </selection>
            </form>
        </option>
        <option id="society.main">
            <form>
              <caption>the Main Characters' Society</caption>
              <selection>
                <option id=""><caption/></option>
                <option id="positive"><caption>Positive</caption></option>
                <option id="negative"><caption>Negative</caption></option>
                <option id="ambiguous"><caption>Ambiguous</caption></option>
              </selection>
            </form>
        </option>
        <option id="existence.reader">
            <form>
              <caption>the Reader's Individual Existence</caption>
              <selection>
                <option id=""><caption/></option>
                <option id="positive"><caption>Positive</caption></option>
                <option id="negative"><caption>Negative</caption></option>
                <option id="ambiguous"><caption>Ambiguous</caption></option>
              </selection>
            </form>
        </option>
        <option id="society.reader">
            <form>
              <caption>the Reader's society</caption>
              <selection>
                <option id=""><caption/></option>
                <option id="positive"><caption>Positive</caption></option>
                <option id="negative"><caption>Negative</caption></option>
                <option id="ambiguous"><caption>Ambiguous</caption></option>
              </selection>
            </form>
        </option>
        <option id="none">
            <form>
              <caption>None of the Above</caption>
              <selection>
                <option id=""><caption/></option>
                <option id="positive"><caption>Positive</caption></option>
                <option id="negative"><caption>Negative</caption></option>
                <option id="ambiguous"><caption>Ambiguous</caption></option>
              </selection>
            </form>
        </option>
      </selection>
      <selection id="closure">
        <caption>Does this ending provide closure?</caption>
        <option id=""><caption/></option>
        <option id="yes"><caption>Yes</caption></option>
        <option id="no"><caption>No</caption></option>
        <option id="somewhat"><caption>Somewhat</caption></option>
      </selection>
    </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/fantasy_content" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content><form>
    <form id="story.fantasy.content">
      <caption>Fantasy Content</caption>
      <selection id="justification" count="multiple">
        <caption>
Mark all that substantially apply (can not be excluded from the story):
        </caption>
        <option id="allohistory"><caption>Allohistory</caption></option>
        <option id="future"><caption>Future</caption></option>
        <option id="past.prehistoric"><caption>Prehistoric Past</caption></option>
        <option id="travel.time"><caption>Time Travel</caption></option>
        <option id="geography.alternative"><caption>Alternative Geography</caption></option>
        <option id="being.extraterrestrial"><caption>Extraterrestrial Being</caption></option>
        <option id="being.mystical"><caption>Mystical Being</caption></option>
        <option id="ability.superhuman"><caption>Superhuman Ability</caption></option>
        <option id="swordsorcery"><caption>Sword and Sorcery</caption></option>
        <option id="magic"><caption>Magic / Anti-Logic</caption></option>
        <option id="utopia"><caption>Utopia / Dystopia</caption></option>
        <option id="advance.scientific"><caption>Scientific Advance</caption></option>
        <option id="invention"><caption>Invention</caption></option>
        <option id="ship.space"><caption>Space Ship</caption></option>
      </selection>
    </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/literary_form" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.literary.form">
        <caption>Literary Form</caption>
        <selection id="appeal" count="multiple">
          <caption>
In which of the following literary modes was the story written?
          </caption>
 [% modes = [
      { id => 'allegory',           desc => 'Allegory / Exemplum / Didactic Tale' },
      { id => 'satire',             desc => 'Satire / Parody'                     },
      { id => 'tale.philosophical', desc => 'Philosophical Tale'                  },
      { id => 'mystery',            desc => 'Mystery'                             },
      { id => 'adventure',          desc => 'Adventure / Picaresque'              },
      { id => 'bildungsroman',      desc => 'Bildungsroman'                       },
      { id => 'story.love',         desc => 'Love Story'                          },
      { id => 'anthropological',    desc => "Anthropological (Myth / Fable / Folk Tale / Children's Tale" },
      { id => 'gothic',             desc => 'Gothic / Ghost Story / Horror'       },
      { id => 'magic',              desc => 'Magic(al) Realism'                   },
      { id => 'fiction.meta',       desc => 'Metafiction'                         },
    ]
 %]
 [% FOREACH modes %]
          <option id="[% id %]"><caption>[% desc %]</caption></option>
 [% END %]
        </selection>
      </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/dominant_science" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.science">
        <caption>Dominant Science</caption>
        <selection id="dominant" count="multiple">
          <caption>
Which of the following best represent(s) the Science according to 
which the defining principles/details of the story are arranged?
          </caption>
          <option id="engineering">
              <form>
                  <caption>Engineering (applied science)</caption>
                <selection>
                  <option id=""><caption/></option>
                  <option id="chemistry"><caption>Chemical</caption></option>
                  <option id="civil"><caption>Civil</caption></option>
                  <option id="computer"><caption>Computer</caption></option>
                  <option id="biology"><caption>Biological</caption></option>
                  <option id="physics"><caption>Physical (Material Science / Mechanical)</caption></option>
                  <option id="undecided"><caption>Undecided</caption></option>
                  <option id="none"><caption>None of these</caption></option>
                </selection>
              </form>
          </option>
          <option id="science.life">
              <form>
                  <caption>Life Science</caption>
                <selection>
                  <option id=""><caption/></option>
                  <option id="biology"><caption>Biology</caption></option>
                  <option id="ecology"><caption>Ecology</caption></option>
                  <option id="medicine"><caption>Medicine</caption></option>
                  <option id="undecided"><caption>Undecided</caption></option>
                  <option id="none"><caption>None of these</caption></option>
                </selection>
              </form>
          </option>
          <option id="mathematics">
              <form>
                  <caption>Mathematics</caption>
                <selection>
                  <option id=""><caption/></option>
                  <option id="algebra"><caption>Algebra</caption></option>
                  <option id="calculus"><caption>Calculus</caption></option>
                  <option id="computerscience"><caption>Computer Science</caption></option>
                  <option id="geometry"><caption>Geometry</caption></option>
                  <option id="music"><caption>Music</caption></option>
                  <option id="statistics"><caption>Statistics</caption></option>
                  <option id="undecided"><caption>Undecided</caption></option>
                  <option id="none"><caption>None of these</caption></option>
                </selection>
              </form>
          </option>
          <option id="science.physical">
              <form>
                  <caption>Physical Science</caption>
                <selection>
                  <option id=""><caption/></option>
                  <option id="chemistry"><caption>Chemistry</caption></option>
                  <option id="geology"><caption>Geology</caption></option>
                  <option id="physics">
                      <form>
                          <caption>Physics</caption>
                        <selection>
                          <option id=""><caption/></option>
                          <option id="astronomy"><caption>Astronomy</caption></option>
                          <option id="quantum"><caption>Quantum</caption></option>
                        </selection>
                      </form>
                  </option>
                  <option id="undecided"><caption>Undecided</caption></option>
                  <option id="none"><caption>None of these</caption></option>
                </selection>
              </form>
          </option>
          <option id="science.social">
              <form>
                  <caption>Social Science</caption>
                <selection>
                  <option id=""><caption/></option>
                  <option id="anthropology"><caption>Anthropology</caption></option>
                  <option id="architecture"><caption>Architecture</caption></option>
                  <option id="economics"><caption>Economics</caption></option>
                  <option id="geography"><caption>Geography</caption></option>
                  <option id="history"><caption>History</caption></option>
                  <option id="linguistics"><caption>Linguistics</caption></option>
                  <option id="pedagogy"><caption>Pedagogy</caption></option>
                  <option id="politicalscience"><caption>Political Science</caption></option>
                  <option id="psychology"><caption>Psychology</caption></option>
                  <option id="sociology"><caption>Sociology</caption></option>
                  <option id="undecided"><caption>Undecided</caption></option>
                  <option id="none"><caption>None of these</caption></option>
                </selection>
              </form>
          </option>
          <option id="none"><caption>Not Applicable</caption></option>
          <option id="other">
              <form>
                  <caption>Other:</caption>
                <textline>
                </textline>
              </form>
          </option>
        </selection>
      </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/hard_sf" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.sf.hard">
        <caption>Hard SF</caption>
        <selection id="step_1">
          <caption>
1. Is/are there (a) thing or phenomenon(a) that suggests / presents 
evidence to support the existence of technology or complex laws of 
nature, physics, etc?
          </caption>
          <option id=""><caption/></option>
          <option id="yes"><caption>Yes (next question)</caption></option>
          <option id="no"><caption>No (not Hard SF)</caption></option>
        </selection>
        <selection id="step_2">
          <caption>
2. Is/ Are the above coded element(s) treated as magic or rationally?
          </caption>
          <option id=""><caption/></option>
          <option id="yes"><caption>Treated as rational (next question)</caption></option>
          <option id="no"><caption>Treated as magic (not Hard SF)</caption></option>
        </selection>
        <selection id="step_3">
          <caption>
3. Is/Are there (a) technical explanation(s) for the occurrence / existence    of the technology / phenomenon? 
          </caption>
          <option id=""><caption/></option>
          <option id="yes"><caption>Yes (next question)</caption></option>
          <option id="no"><caption>No (not Hard SF)</caption></option>
        </selection>
        <selection id="step_4">
          <caption>
4. Is/Are the technical explanation(s) intended to be credible within the context    of the story? 
          </caption>
          <option id=""><caption/></option>
          <option id="yes"><caption>Yes (Hard SF)</caption></option>
          <option id="no"><caption>No (not Hard SF)</caption></option>
        </selection>
      </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/literary_conflict" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.conflict.literary">
        <caption>Literary Conflict</caption>
        <selection count="multiple">
          <caption>
Which of the following conflicts is/are dominant in the story?
          </caption>
          <option id="individual.individual">
                <caption>individual vs. individual</caption>
          </option>
          <option id="individual.nature">
                <caption>individual vs. nature (Homo re. Nature)</caption>
          </option>
          <option id="individual.other">
                <caption>individual vs. other</caption>
          </option>
          <option id="individual.self">
                <caption>individual vs. self</caption>
          </option>
          <option id="individual.society">
                <caption>individual vs. society</caption>
          </option>
          <option id="group.inter">
                <caption>intergroup conflict</caption>
          </option>
          <option id="group.intra">
                <caption>intragroup conflict</caption>
          </option>
          <option id="individual.tech">
                <caption>individual/society vs. technology</caption>
          </option>
          <option id="transcendental">
                <caption>transcends conflict</caption>
          </option>
        </selection>
      </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/theme" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.theme">
        <caption>Thematic Data</caption>
        <selection count="multiple">
[% themes = [
      { id => 'alienness',           desc => 'Alienness / Difference / Assimilation' },
      { id => 'arts',                desc => 'The Arts'                              },
      { id => 'communication',       desc => 'Communication'                         },
      { id => 'conquest',            desc => 'Conquest / Domination'                 },
      { id => 'escapism',            desc => 'Escapism'                              },
      { id => 'gender',              desc => 'Gender / Sexuality'                    },
      { id => 'heroism',             desc => 'Heroism'                               },
      { id => 'education',           desc => 'Individual Education / Coming of Age'  },
      { id => 'justice',             desc => 'Justice / Injustice'                   },
      { id => 'literacy',            desc => 'Literacy / Orailty'                    },
      { id => 'philosophy',          desc => 'Philosophy / The Sacred'               },
      { id => 'conflict.political',  desc => 'Political Conflict / Power Struggle'   },
      { id => 'progress.scientific', desc => 'Science / Scientific Progress'         },
      { id => 'security',            desc => 'Security / Defense'                    },
      { id => 'progress.social',     desc => 'Social Progress / Class'               },
   ]
%]

[% FOREACH themes %]
          <option id="[% id %]"><caption>[% desc %]</caption></option>
[% END %]
        </selection>
      </form>   
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML


        "$base/coding/narrative" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.narrative">
        <caption>Narrative Data</caption>
        <selection id="plot.duration">
          <caption>Plot Duration</caption>
          <option id=""><caption/></option>
          <option id="hours"><caption>Minutes to Hours (24 or fewer)</caption></option>
          <option id="days"><caption>2 - 7 Days</caption></option>
          <option id="weeks"><caption>2 - 8 Weeks</caption></option>
          <option id="months"><caption>2 - 24 Months</caption></option>
          <option id="years"><caption>2 or more Years</caption></option>
          <option id="life"><caption>Lifetime</caption></option>
          <option id="generation"><caption>Generations</caption></option>
          <option id="race"><caption>Racial Memory</caption></option>
          <option id="other"><caption>Other</caption></option>
        </selection>
        <selection id="plot.form">
          <caption>Plot Form</caption>
          <option id=""><caption/></option>
          <option id="epistolary"><caption>Epistolary</caption></option>
          <option id="linear.epistolary"><caption>Linear-Epistolary</caption></option>
          <option id="linear.integrated"><caption>Linear-Integrated</caption></option>
          <option id="nested"><caption>Nested</caption></option>
          <option id="circular"><caption>Circular</caption></option>
          <option id="architectonic"><caption>Architectonic</caption></option>
          <option id="other"><caption>Other</caption></option>
        </selection>
        <selection id="story.duration">
          <caption>Story Duration</caption>
          <option id=""><caption/></option>
          <option id="hours"><caption>Minutes to Hours (24 or fewer)</caption></option>
          <option id="days"><caption>2 - 7 Days</caption></option>
          <option id="weeks"><caption>2 - 8 Weeks</caption></option>
          <option id="months"><caption>2 - 24 Months</caption></option>
          <option id="years"><caption>2 or more Years</caption></option>
          <option id="life"><caption>Lifetime</caption></option>
          <option id="generation"><caption>Generations</caption></option>
          <option id="race"><caption>Racial Memory</caption></option>
          <option id="other"><caption>Other</caption></option>
        </selection>
        <selection id="style.sentence">
          <caption>Predominant Sentence Style</caption>
          <option id=""><caption/></option>
          <option id="propositional"><caption>Propositional</caption></option>
          <option id="metaphorical"><caption>Metaphorical</caption></option>
          <option id="ironic"><caption>Ironic</caption></option>
          <option id="other"><caption>Other</caption></option>
          <option id="mixed">
              <form>
                <caption>Mixed:</caption>
                <textline/>
              </form>
          </option>
          <option id="none"><caption>Not Applicable</caption></option>
        </selection>
        <selection id="style.overall">
          <caption>Overall Style</caption>
          <option id=""><caption/></option>
          <option id="propositional"><caption>Propositional</caption></option>
          <option id="metaphorical"><caption>Metaphorical</caption></option>
          <option id="ironic"><caption>Ironic</caption></option>
          <option id="other"><caption>Other</caption></option>
          <option id="mixed">
              <form>
                <caption>Mixed:</caption>
                <textline/>
              </form>
          </option>
          <option id="none"><caption>Not Applicable</caption></option>
        </selection>
      </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/character" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.character">
        <caption>Character Data</caption>
        <selection id="round">
          <caption>Number of round:</caption>
          <option id=""><caption/></option>
          <option id="0"><caption>1 only</caption></option>
          <option id="0.5"><caption>2-4</caption></option>
          <option id="1"><caption>5-10</caption></option>
          <option id="1.5"><caption>scores</caption></option>
          <option id="2"><caption>hundreds</caption></option>
          <option id="3"><caption>thousands</caption></option>
          <option id="6"><caption>millions</caption></option>
        </selection>
        <selection id="flat">
          <caption>Number of flat:</caption>
          <option id=""><caption/></option>
          <option id="0"><caption>1 only</caption></option>
          <option id="0.5"><caption>2-4</caption></option>
          <option id="1"><caption>5-10</caption></option>
          <option id="1.5"><caption>scores</caption></option>
          <option id="2"><caption>hundreds</caption></option>
          <option id="3"><caption>thousands</caption></option>
          <option id="6"><caption>millions</caption></option>
        </selection>
        <selection id="static">
          <caption>Number of static:</caption>
          <option id=""><caption/></option>
          <option id="0"><caption>1 only</caption></option>
          <option id="0.5"><caption>2-4</caption></option>
          <option id="1"><caption>5-10</caption></option>
          <option id="1.5"><caption>scores</caption></option>
          <option id="2"><caption>hundreds</caption></option>
          <option id="3"><caption>thousands</caption></option>
          <option id="6"><caption>millions</caption></option>
        </selection>
        <selection id="dynamic">
          <caption>Number of static:</caption>
          <option id=""><caption/></option>
          <option id="0"><caption>1 only</caption></option>
          <option id="0.5"><caption>2-4</caption></option>
          <option id="1"><caption>5-10</caption></option>
          <option id="1.5"><caption>scores</caption></option>
          <option id="2"><caption>hundreds</caption></option>
          <option id="3"><caption>thousands</caption></option>
          <option id="6"><caption>millions</caption></option>
        </selection>
      </form>
      <form>
        <caption>Main Characters</caption>
        [% IF out.story.character.main.size() %]
          <selection id="main" count="multiple">
            [% FOREACH out.story.character.main %]
              <option id="[% loop.index() %]">
                <caption>
                  Character [% loop.index() + 1 %]
                  [% IF name %]
                    - [% name | html %]
                  [% END %]
                </caption>
              </option>
            [% END %]
          </selection>
        [% ELSE %]
          <text><para>
You need to add a main character.
          </para></text>
        [% END %]
        <submit id="action.add"><caption>Add</caption></submit>
        [% IF out.story.character.main.size() %]
          <submit id="action.edit"><caption>Edit</caption></submit>
        [% END %]
        <reset/>
        [% IF out.story.character.main.size() %]
          <submit id="action.delete"><caption>Delete</caption></submit>
        [% END %]
      </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/main" => <<'EOXML',
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="main">
        <caption>Main Character</caption>
        <textline id="name" required="1"><caption>Name:</caption></textline>
        <selection id="species">
          <caption>Type / Species:</caption>
          <option id=""><caption/></option>
          <option id="human"><caption>Human</caption></option>
          <option id="animal"><caption>Animal</caption></option>
          <option id="alien"><caption>Alien</caption></option>
          <option id="robot"><caption>Robot/Machine</caption></option>
          <option id="metamorph"><caption>Metamorph</caption></option>
          <option id="other"><caption>Other</caption></option>
          <option id="none"><caption>Not Applicable</caption></option>
        </selection>
        <selection id="dimensions">
          <caption>Dimensions:</caption>
          <option id=""><caption/></option>
          <option id="flat"><caption>Flat</caption></option>
          <option id="round"><caption>Round</caption></option>
        </selection>
        <selection id="gender">
          <caption>Gender:</caption>
          <option id=""><caption/></option>
          <option id="male"><caption>Male</caption></option>
          <option id="female"><caption>Female</caption></option>
          <option id="other"><caption>Other</caption></option>
        </selection>
        <selection id="age">
          <caption>Age:</caption>
          <option id=""><caption/></option>
          <option id="child"><caption>Child</caption></option>
          <option id="adolescent"><caption>Adolescent</caption></option>
          <option id="post_adolescent"><caption>Post-Adolescent</caption></option>
          <option id="mid_life"><caption>Mid-Life Crisis</caption></option>
          <option id="old_adult"><caption>Old Adult</caption></option>
          <option id="timeless"><caption>Timeless</caption></option>
          <option id="none"><caption>Not Applicable</caption></option>
        </selection>
      </form>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.save"><caption>Save</caption></submit>
    </form>
  </content>
</container>
EOXML

        "$base/coding/supp_bio" => <<'EOXML'
<container>
  <title>GEP Coding</title>
  <content>
    <form>
      <form id="story.supp.bio">
        <caption>Supplemental Question #1: Biological Interest</caption>
        <selection id="involvement" count="multiple">
          <caption>
Are any of the major characters involved in/affiliated with or by the following?
          </caption>
          <option id="reproductive.capable">
            <form>
              <caption>Reproductive capable</caption>
              <selection>
                <option id=""><caption/></option>
                <option id='attraction'><caption>Attraction</caption></option>
                <option id='love'><caption>Love</caption></option>
                <option id='sex'><caption>Sex</caption></option>
                <option id='rape'><caption>Rape</caption></option>
              </selection>
            </form>
          </option>
          <option id='reproductive.incapable'>
            <form>
              <caption>Non-Reproductive</caption>
              <selection>
                <option id=""><caption/></option>
                <option id='attraction'><caption>Attraction</caption></option>
                <option id='love'><caption>Love</caption></option>
                <option id='sex'><caption>Sex</caption></option>
                <option id='rape'><caption>Rape</caption></option>
              </selection>
            </form>
          </option>
          <option id='marriage'>
            <form>
              <caption>Marriage</caption>
              <group>
                <selection id="number">
                  <option id=""><caption/></option>
                  <option id="1"><caption>Monogomous</caption></option>
                  <option id="2"><caption>Polygomous</caption></option>
                </selection>
                <selection id="sexuality">
                  <option id=""><caption/></option>
                  <option id="heterosexual"><caption>Heterosexual</caption></option>
                  <option id="bisexual"><caption>Bisexual</caption></option>
                  <option id="homosexual"><caption>Homosexual</caption></option>
                </selection>
              </group>
            </form>
          </option>
          <option id='homosexual'>
            <form>
              <caption>Non-Reproductive</caption>
              <selection>
                <option id=""><caption/></option>
                <option id='attraction'><caption>Attraction</caption></option>
                <option id='love'><caption>Love</caption></option>
                <option id='sex'><caption>Sex</caption></option>
                <option id='rape'><caption>Rape</caption></option>
              </selection>
            </form>
          </option>
          <option id='bisexual'>
            <form>
              <caption>Non-Reproductive</caption>
              <selection>
                <option id=""><caption/></option>
                <option id='attraction'><caption>Attraction</caption></option>
                <option id='love'><caption>Love</caption></option>
                <option id='sex'><caption>Sex</caption></option>
                <option id='rape'><caption>Rape</caption></option>
              </selection>
            </form>
          </option>
          <option id="adultery">
            <form>
              <caption>Adultery</caption>
              <selection>
                <caption> - as the </caption>
                <option id=""><caption/></option>
                <option id="perpetrator"><caption>Perpetrator</caption></option>
                <option id="victim"><caption>Victim</caption></option>
              </selection>
            </form>
          </option>
          <option id="incest">
            <form>
              <caption>Incest</caption>
              <group>
                <selection id="sexuality">
                  <caption>:</caption>
                  <option id=""><caption/></option>
                  <option id="heterosexual"><caption>Heterosexual</caption></option>
                  <option id="homosexual"><caption>Homosexual</caption></option>
                </selection>
                <selection id="willingness">
                  <caption> - as </caption>
                  <option id=""><caption/></option>
                  <option id="willing"><caption>Willing</caption></option>
                  <option id="unwilling"><caption>Unwilling</caption></option>
                </selection>
              </group>
            </form>
          </option>
          <option id="familial">
            <caption>Familial (non-sexual) relationship(s)</caption>
          </option>
          <option id="genetic">
            <form>
              <caption>Genetic</caption>
              <group>
                <selection id="usefullness">
                  <option id=""><caption/></option>
                  <option id="defect"><caption>Defect</caption></option>
                  <option id="enhancement"><caption>Enhancement</caption></option>
                </selection>
                <selection id="cause">
                  <caption> - caused by </caption>
                  <option id=""><caption/></option>
                  <option id="biological"><caption>Biological Mutation</caption></option>
                  <option id="genetic"><caption>Genetic Modification</caption></option>
                </selection>
              </group>
            </form>
          </option>
        </selection>
      </form>
      <submit id="action.prev"><caption>Prev</caption></submit>
      <reset/>
      <submit id="action.discard"><caption>Cancel</caption></submit>
      <submit id="action.next"><caption>Next</caption></submit>
    </form>
  </content>
</container>
EOXML
    },

    xsm => {
        "$base/coding" => <<'EOXML'
<?xml-stylesheet file="/sys/xsm/wizard" type="xslt" ?>
<statemachine
  xmlns="http://ns.gestinanna.org/statemachine"
  xmlns:gst="http://ns.gestinanna.org/gestinanna"
  xmlns:wiz="http://ns.gestinanna.org/xsm/xsl/wizard"
>
  <state id="discard">
    <script when="pre">
      <value name="/story"><association/></value>
      <goto state="_begin"/>
    </script>
  </state>

  <wiz:steps>
    <filter id="trim"/>
    <wiz:step view="publication">
      <variable id="story.publication.title"/>
      <variable id="story.publication.author"/>
      <variable id="story.publication.category"/>
      <variable id="story.publication.year"/>
    </wiz:step>

    <wiz:step view="story">
      <variable id="story.narrative.person" dependence="OPTIONAL"/>
      <variable id="story.narrative.tense" dependence="OPTIONAL"/>
      <variable id="story.setting.time" dependence="OPTIONAL"/>
      <variable id="story.setting.locale" dependence="OPTIONAL"/>
    </wiz:step>

    <wiz:step view="character" alias="character">
      <variable id="story.character.round" dependence="OPTIONAL"/>
      <variable id="story.character.flat" dependence="OPTIONAL"/>
      <variable id="story.character.static" dependence="OPTIONAL"/>
      <variable id="story.character.dynamic" dependence="OPTIONAL"/>

      <transition state="main_add">
        <variable id="action.add"/>
        <script>
          <value name="/position/main" select="-1"/>
          <value name="/placement/main" select="'end'"/>
          <value name="/main"><association/></value>
          <goto state="main_edit"/>
        </script>
      </transition>

      <transition state="main_edit">
        <variable id="action.edit"/>
        <variable id="main"/>
        <script>
          <value name="/position/main" select="/main"/>
          <value name="/placement/main" select="'inplace'"/>
          <variable name="id" select="/main"/>
          <value name="/main" select="clone(/story/character/main/{$id})"/>
        </script>
      </transition>

      <transition state="main_delete">
        <variable id="action.delete"/>
        <variable id="main"/>
        <script>
          <assert test="count(list(/main)/*) >= 1" state="character"/>
          <for-each select="/story/character/main/*">
            <sort select="1000 - ."/> <!-- make sure we can numerically sort in reverse order -->
            <value name="/story/character/main" select="splice(list(/story/character/main)/*, ., 1)"/>
          </for-each>
          <goto state="character"/>
        </script>
      </transition>
    </wiz:step>

    <wiz:step view="conclusion">
      <variable id="story.conclusion.ending.value" dependence="OPTIONAL"/>
      <variable id="story.conclusion.ending.existence.main" dependence="OPTIONAL"/>
      <variable id="story.conclusion.ending.society.main" dependence="OPTIONAL"/>
      <variable id="story.conclusion.ending.existence.reader" dependence="OPTIONAL"/>
      <variable id="story.conclusion.ending.society.reader" dependence="OPTIONAL"/>
      <variable id="story.conclusion.ending.none" dependence="OPTIONAL"/>
      <variable id="story.conclusion.closure" dependence="OPTIONAL"/>
    </wiz:step>

    <wiz:step view="fantasy_content">
      <variable id="story.fantasy.content.justification" dependence="OPTIONAL"/>
    </wiz:step>

    <wiz:step view="literary_form">
      <variable id="story.literary.form.appeal" dependence="OPTIONAL"/>
    </wiz:step>

    <wiz:step view="dominant_science">
      <group id="story.science.dominant" dependence="OPTIONAL">
        <variable id="value"/>
        <variable id="engineering"/>
        <variable id="science.life"/>
        <variable id="mathematics"/>
        <variable id="science.physical.value"/>
        <variable id="science.physical.physics"/>
        <variable id="science.social"/>
        <variable id="other"/>
      </group>
    </wiz:step>

    <wiz:step view="hard_sf">
      <group id="story.sf.hard" dependence="OPTIONAL">
        <variable id="step_1"/>
        <variable id="step_2"/>
        <variable id="step_3"/>
        <variable id="step_4"/>
      </group>
    </wiz:step>

    <wiz:step view="literary_conflict">
      <variable id="story.conflict.literary" dependence="OPTIONAL"/>
    </wiz:step>

    <wiz:step view="theme">
      <variable id="story.theme" dependence="OPTIONAL"/>
    </wiz:step>

    <wiz:step view="supp_bio">
      <group id="story.supp.bio.involvement" dependence="OPTIONAL">
        <variable id="value"/>
        <variable id="reproductive.capable"/>
        <variable id="reproductive.incapable"/>
        <variable id="marriage.number"/>
        <variable id="marriage.sexuality"/>
        <variable id="homosexual"/>
        <variable id="bisexual"/>
        <variable id="adultery"/>
        <variable id="incest.sexuality"/>
        <variable id="incest.willingness"/>
        <variable id="genetic.usefullness"/>
        <variable id="genetic.cause"/>
      </group>
    </wiz:step>

    <!--
    <wiz:step view="supp_psyc">
    </wiz:step>
    -->
  </wiz:steps>

  <state id="main_edit" view="main">
    <transition state="save_main">
      <variable id="action.save"/>
      <variable id="main.name"/>
      <variable id="main.species" dependence="OPTIONAL"/>
      <variable id="main.dimensions" dependence="OPTIONAL"/>
      <variable id="main.gender" dependence="OPTIONAL"/>
      <variable id="main.age" dependence="OPTIONAL"/>
      <script>
        <choose>
          <when test="/position/main = -1"> <!-- adding to end -->
            <value name="/story/character/main" select="list(/story/character/main | /main)"/>
          </when>
          <when test="/placement/main = 'insert'">
            <value name="/story/character/main" select="splice(list(/story/character/main)/*, /position/main, 0, /main)"/>
          </when>
          <when test="/placement/main = 'inplace'">
            <value name="/story/character/main" select="splice(list(/story/character/main)/*, /position/main, 1, /main)"/>
          </when>
        </choose>
        <value name="/main" select="null()"/>
        <goto state="character"/>

      </script>
    </transition>

    <transition state="character">
      <variable id="action.discard"/>
    </transition>
  </state>

  <state id="finish">
    <script when="pre">
      <!-- put your code here to do something with the information
           you've gathered
         -->
    </script>
  </state>

</statemachine>
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
