use strict;
use warnings;

use Test::More tests => 14;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->new;
is $sqla->generate( [ -name => qw/me id/]), "me.id",
  "Simple name generator";

is $sqla->generate(
  [ -list => 
    [ -name => qw/me id/],
    [ -name => qw/me foo bar/],
    [ -name => qw/bar/]
  ] 
), "me.id, me.foo.bar, bar",
  "List generator";

is $sqla->generate(
  [ -alias => [ -name => qw/me id/], "foobar", ] 
), "me.id AS foobar",
  "Alias generator";

is $sqla->generate(
  [ -order_by => [ -name => qw/me date/ ] ]
), "ORDER BY me.date";

is $sqla->generate(
  [ -order_by => 
    [ -name => qw/me date/ ],
    [ -name => qw/me foobar/ ],
  ]
), "ORDER BY me.date, me.foobar";

is $sqla->generate(
  [ -order_by => [ -desc => [ -name => qw/me date/ ] ] ]
), "ORDER BY me.date DESC";


is $sqla->generate(
  [ -where =>
      [ '>', [-name => qw/me id/], [-value => 500 ] ]
  ]
), "WHERE me.id > ?", "where clause";

eq_or_diff( [ SQL::Abstract->generate(
    [ -where =>
        [ '>', [-name => qw/me id/], [-value => 500 ] ],
        [ '==', [-name => qw/me name/], [-value => '200' ] ]
    ]
  ) ], 
  [ "WHERE me.id > ? AND me.name = ?",
    [ 500,
      '200'
    ]
  ],
  "Where with binds"
);


is $sqla->generate(
  [ -where =>  -or =>
      [ '>', [-name => qw/me id/], [-value => 500 ] ],
      [ '==', [-name => qw/me name/], [-value => '200' ] ],
  ]
), "WHERE me.id > ? OR me.name = ?", "where clause";


is $sqla->generate(
  [ -where =>  -or =>
      [ '>', [-name => qw/me id/], [-value => 500 ] ],
      [ -or => 
        [ '==', [-name => qw/me name/], [-value => '200' ] ],
        [ '==', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id > ? OR me.name = ? OR me.name = ?", "where clause";

is $sqla->generate(
  [ -where =>  -or =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -and => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? OR me.name > ? AND me.name < ?", "where clause";

is $sqla->generate(
  [ -where =>  -and =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -and => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? AND me.name > ? AND me.name < ?", "where clause";


is $sqla->generate(
  [ -where =>  -and =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -or => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? AND (me.name > ? OR me.name < ?)", "where clause";
