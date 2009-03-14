use strict;
use warnings;

use Test::More tests => 4;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

is $sqla->dispatch(
  { -type => 'join',
    args => [
      {-type => name => args => [qw/bar/]},
      {-type => name => args => [qw/foo/]},
    ],
    on => { 
      -type => 'expr',
      op => '==',
      args => [
        { -type => 'name', args => [qw/foo id/] },
        { -type => 'name', args => [qw/me foo_id/] },
      ]
    }
  }
), "bar JOIN foo ON (foo.id = me.foo_id)", 
   "simple join clause";

is $sqla->dispatch(
  { -type => 'join',
    args => [
      {-type => name => args => [qw/fnord/]},
      {-type => 'alias', ident => {-type => name => args => [qw/foo/]}, as => 'bar' }
    ],
    using => { -type => 'name', args => [qw/foo_id/] },
  }
), "fnord JOIN foo AS bar USING (foo_id)", 
   "using join clause";


is $sqla->dispatch(
  { -type => 'join',
    join_type => 'LEFT',
    args => [
      {-type => name => args => [qw/fnord/]},
      {-type => 'alias', ident => {-type => name => args => [qw/foo/]}, as => 'bar' }
    ],
    using => { -type => 'name', args => [qw/foo_id/] },
  }
), "fnord LEFT JOIN foo AS bar USING (foo_id)", 
   "using left join clause";
