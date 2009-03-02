use strict;
use warnings;

use Test::More tests => 9;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

    $DB::single = 1;
is SQL::Abstract->generate( [ -name => qw/me id/]), "me.id",
  "Simple name generator";

is SQL::Abstract->generate(
  [ -list => 
    [ -name => qw/me id/],
    [ -name => qw/me foo bar/],
    [ -name => qw/bar/]
  ] 
), "me.id, me.foo.bar, bar",
  "List generator";

is SQL::Abstract->generate(
  [ -alias => [ -name => qw/me id/], "foobar", ] 
), "me.id AS foobar",
  "Alias generator";

is SQL::Abstract->generate(
  [ -where =>
      [ '>', [-name => qw/me.id/], [-value => 500 ] ]
  ]
), "WHERE me.id > ?", "where clause";


is SQL::Abstract->generate(
  [ -where =>
      [ '>', [-name => qw/me.id/], [-value => 500 ] ],
      [ '==', [-name => qw/me.name/], [-value => '200' ] ]
  ]
), "WHERE me.id > ? AND me.name = ?", "where clause";


is SQL::Abstract->generate(
  [ -where =>  -or =>
      [ '>', [-name => qw/me.id/], [-value => 500 ] ],
      [ '==', [-name => qw/me.name/], [-value => '200' ] ],
  ]
), "WHERE me.id > ? OR me.name = ?", "where clause";


is SQL::Abstract->generate(
  [ -where =>  -or =>
      [ '>', [-name => qw/me.id/], [-value => 500 ] ],
      [ -or => 
        [ '==', [-name => qw/me.name/], [-value => '200' ] ],
        [ '==', [-name => qw/me.name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id > ? OR me.name = ? OR me.name = ?", "where clause";

is SQL::Abstract->generate(
  [ -where =>  -or =>
      [ '==', [-name => qw/me.id/], [-value => 500 ] ],
      [ -and => 
        [ '>', [-name => qw/me.name/], [-value => '200' ] ],
        [ '<', [-name => qw/me.name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? OR (me.name > ? AND me.name < ?)", "where clause";
