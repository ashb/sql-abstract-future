use strict;
use warnings;

use Test::More tests => 15;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->new(ast_version => 1);
is $sqla->dispatch( [ -name => qw/me id/]), "me.id",
  "Simple name generator";

is $sqla->dispatch(
  [ -list => 
    [ -name => qw/me id/],
    [ -name => qw/me foo bar/],
    [ -name => qw/bar/]
  ] 
), "me.id, me.foo.bar, bar",
  "List generator";

is $sqla->dispatch(
  [ -alias => [ -name => qw/me id/], "foobar", ] 
), "me.id AS foobar",
  "Alias generator";

is $sqla->dispatch(
  [ -order_by => [ -name => qw/me date/ ] ]
), "ORDER BY me.date";

is $sqla->dispatch(
  [ -order_by => 
    [ -name => qw/me date/ ],
    [ -name => qw/me foobar/ ],
  ]
), "ORDER BY me.date, me.foobar";

is $sqla->dispatch(
  [ -order_by => [ -desc => [ -name => qw/me date/ ] ] ]
), "ORDER BY me.date DESC";


is $sqla->dispatch(
  [ -where =>
      [ '>', [-name => qw/me id/], [-value => 500 ] ]
  ]
), "WHERE me.id > ?", "where clause";

eq_or_diff( [ SQL::Abstract->generate(
    [ -ast_version => 1,
      -where =>
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


is $sqla->dispatch(
  [ -where =>  -or =>
      [ '>', [-name => qw/me id/], [-value => 500 ] ],
      [ '==', [-name => qw/me name/], [-value => '200' ] ],
  ]
), "WHERE me.id > ? OR me.name = ?", "where clause";


is $sqla->dispatch(
  [ -where =>  -or =>
      [ '>', [-name => qw/me id/], [-value => 500 ] ],
      [ -or => 
        [ '==', [-name => qw/me name/], [-value => '200' ] ],
        [ '==', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id > ? OR me.name = ? OR me.name = ?", "where clause";

is $sqla->dispatch(
  [ -where =>  -or =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -and => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? OR me.name > ? AND me.name < ?", "where clause";

is $sqla->dispatch(
  [ -where =>  -and =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -and => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? AND me.name > ? AND me.name < ?", "where clause";


is $sqla->dispatch(
  [ -where =>  -and =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -or => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? AND (me.name > ? OR me.name < ?)", "where clause";

eq_or_diff(
  [SQL::Abstract->generate(
    [ -ast_version => 1,
      -where =>
      [ -in => 
        [-name => qw/me id/],
        [-value => '100' ],
        [-value => '200' ],
        [-value => '300' ],
      ]
    ]
  ) ],

  [ "WHERE me.id IN (?, ?, ?)", 
    [ qw/100 200 300/]
  ],
  
  "where IN clause");
