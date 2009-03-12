use strict;
use warnings;

use Test::More tests => 12;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

is $sqla->dispatch(
  { -type => 'expr',
    op => '>',
    args => [
      {-type => name => args => [qw/me id/] }, 
      { -type => 'value', value => 500 }
    ]
  }
), "me.id > ?", 
   "simple where clause";
__END__
is $sqla->dispatch(
  [ -in => [  ] ]
), "0 = 1", "emtpy -in";

is $sqla->dispatch(
  [ -where =>
      [ '>', [-name => qw/me id/], [-value => 500 ] ]
  ]
), "WHERE me.id > ?", 
   "simple where clause";

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
), "WHERE me.id > ? OR me.name = ?", 
   "where clause (simple or)";


is $sqla->dispatch(
  [ -where =>  -or =>
      [ '>', [-name => qw/me id/], [-value => 500 ] ],
      [ -or => 
        [ '==', [-name => qw/me name/], [-value => '200' ] ],
        [ '==', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id > ? OR me.name = ? OR me.name = ?",
   "where clause (nested or)";

is $sqla->dispatch(
  [ -where =>  -or =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -and => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? OR me.name > ? AND me.name < ?", 
   "where clause (inner and)";

is $sqla->dispatch(
  [ -where =>  -and =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -and => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? AND me.name > ? AND me.name < ?", 
   "where clause (nested and)";


is $sqla->dispatch(
  [ -where =>  -and =>
      [ '==', [-name => qw/me id/], [-value => 500 ] ],
      [ -or => 
        [ '>', [-name => qw/me name/], [-value => '200' ] ],
        [ '<', [-name => qw/me name/], [-value => '100' ] ]
      ]
  ]
), "WHERE me.id = ? AND (me.name > ? OR me.name < ?)", 
   "where clause (inner or)";

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


eq_or_diff(
  [SQL::Abstract->generate(
    [ -ast_version => 1,
      -where =>
      [ -not_in => 
        [-name => qw/me id/],
        [-value => '100' ],
        [-value => '200' ],
        [-value => '300' ],
      ]
    ]
  ) ],

  [ "WHERE me.id NOT IN (?, ?, ?)", 
    [ qw/100 200 300/]
  ],
  
  "where NOT IN clause");
