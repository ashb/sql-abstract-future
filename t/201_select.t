use strict;
use warnings;

use Test::More tests => 3;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

is $sqla->dispatch(
  { -type => 'select',
    from => [-alias => [-name => 'foo'] => 'me' ],
    columns => [ -list => 
        [ -name => qw/me id/ ],
        [ -alias => [ -name => qw/me foo_id/ ], 'foo' ],
    ]
  }
), "SELECT me.id, me.foo_id AS foo FROM foo AS me",
   "simple select clause";

is $sqla->dispatch(
  { -type => 'select',
    from => [-alias => [-name => 'foo'] => 'me' ],
    columns => [ -list => 
        [ -name => qw/me id/ ],
        [ -alias => [ -name => qw/me foo_id/ ], 'foo' ],
        [ -name => qw/bar name/ ],
    ],
    join => {
      tablespec => [-name => qw/bar/],
      on => [ '==', [-name => qw/bar id/], [ -name => qw/me bar_id/ ] ],
    }
  }
), "SELECT me.id, me.foo_id AS foo, bar.name FROM foo AS me JOIN bar ON (bar.id = me.bar_id)", 
   "select with join clause";


