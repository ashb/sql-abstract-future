use strict;
use warnings;

use Test::More tests => 5;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

my $foo_as_me = {
  -type => 'alias', 
  ident => {-type => 'identifier', elements => [qw/foo/]}, 
  as => 'me'
};
my $me_foo_id = { -type => 'identifier', elements => [qw/me foo_id/] };

is $sqla->dispatch(
  { -type => 'select',
    tablespec => $foo_as_me,
    columns => [
      { -type => 'identifier', elements => [qw/me id/] },
      { -type => 'alias', ident => $me_foo_id, as => 'foo' },
    ]
  }
), "SELECT me.id, me.foo_id AS foo FROM foo AS me",
   "simple select clause";

is $sqla->dispatch(
  { -type => 'select',
    columns => [
      { -type => 'identifier', elements => [qw/me id/] },
      { -type => 'alias', ident => $me_foo_id, as => 'foo' },
      { -type => 'identifier', elements => [qw/bar name/] },
    ],
    tablespec => {
      -type => 'join',
      lhs => $foo_as_me,
      rhs => {-type => 'identifier', elements => [qw/bar/] },
      on => {
        -type => 'expr',
        op => '==',
        args => [
          {-type => 'identifier', elements => [qw/bar id/]}, 
          {-type => 'identifier', elements => [qw/me bar_id/]}
        ],
      }
    },
  }


), "SELECT me.id, me.foo_id AS foo, bar.name FROM foo AS me JOIN bar ON (bar.id = me.bar_id)", 
   "select with join clause";


is $sqla->dispatch(
  { -type => 'select',
    columns => [
      { -type => 'identifier', elements => [qw/me */] },
    ],
    tablespec => $foo_as_me,
    where => {
      -type => 'expr',
      op => '==',
      args => [
        {-type => 'identifier', elements => [qw/me id/]},
        {-type => 'value', value => 1 },
      ]
    }
  }


), "SELECT me.* FROM foo AS me WHERE me.id = ?",
   "select with where";


is $sqla->dispatch(
  { -type => 'select',
    tablespec => $foo_as_me,
    columns => [
      { -type => 'identifier', elements => [qw/me id/] },
      { -type => 'alias', ident => $me_foo_id, as => 'foo' },
    ],
    order_by => [
      { -type => 'ordering', expr => { -type => 'identifier', elements => [qw/me name/] }, direction => 'desc' },
      $me_foo_id,
    ]
  }
), "SELECT me.id, me.foo_id AS foo FROM foo AS me ORDER BY me.name DESC, me.foo_id",
   "select clause with order by";
