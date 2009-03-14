use strict;
use warnings;

use Test::More tests => 3;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

is $sqla->dispatch(
  { -type => 'select',
    tablespec => {-type => 'alias', ident => {-type => 'name', args => [qw/foo/]}, as => 'me' },
    columns => [
      { -type => 'name', args => [qw/me id/] },
      { -type => 'alias', ident => { -type => 'name', args => [qw/me foo_id/] }, as => 'foo' },
    ]
  }
), "SELECT me.id, me.foo_id AS foo FROM foo AS me",
   "simple select clause";

is $sqla->dispatch(
  { -type => 'select',
    columns => [
      { -type => 'name', args => [qw/me id/] },
      { -type => 'alias', ident => { -type => 'name', args => [qw/me foo_id/] }, as => 'foo' },
      { -type => 'name', args => [qw/bar name/] },
    ],
    tablespec => {
      -type => 'join',
      lhs => {-type => 'alias', ident => {-type => 'name', args => [qw/foo/]}, as => 'me' },
      rhs => {-type => 'name', args => [qw/bar/] },
      on => {
        -type => 'expr',
        op => '==',
        args => [
          {-type => 'name', args => [qw/bar id/]}, 
          {-type => 'name', args => [qw/me bar_id/]}
        ],
      }
    },
  }


), "SELECT me.id, me.foo_id AS foo, bar.name FROM foo AS me JOIN bar ON (bar.id = me.bar_id)", 
   "select with join clause";

__END__
