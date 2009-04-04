
use strict;
use warnings;

use Test::More tests => 4;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

is $sqla->dispatch(
  { -type => 'expr',
    op => '==',
    args => [
      { -type => 'expr',
        op => 'ROUND',
        args => [
          {-type => identifier => elements => [qw/me id/] }, 
        ]
      },
      { -type => 'expr',
        op => 'ROUND',
        args => [
          { -type => 'value', value => 500 }
        ]
      },
    ]
  }
), "ROUND(me.id) = ROUND(?)", 
   "simple expr clause";

is $sqla->dispatch(
  { -type => 'expr',
    op => 'last_insert_id',
  }
), "last_insert_id()",
   "last_insert_id";

is $sqla->dispatch(
  { -type => 'expr',
    op => 'between',
    args => [
      {-type => identifier => elements => [qw/me id/] }, 
      { -type => 'value', value => 500 },
      { -type => 'value', value => 599 },
    ],
  }
), "(me.id BETWEEN ? AND ?)",
   "between";

