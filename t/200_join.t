use strict;
use warnings;

use Test::More tests => 4;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

my $foo = {-type => identifier => elements => [qw/foo/]};
my $bar = {-type => identifier => elements => [qw/bar/]},
my $fnord = {-type => identifier => elements => [qw/fnord/]};

my $foo_id = { -type => 'identifier', elements => [qw/foo id/] };
my $me_foo_id = { -type => 'identifier', elements => [qw/me foo_id/] };

is $sqla->dispatch(
  { -type => 'join',
    lhs => $bar,
    rhs => $foo,
    on => { 
      -type => 'expr',
      op => '==',
      args => [ $foo_id, $me_foo_id ]
    }
  }
), "bar JOIN foo ON (foo.id = me.foo_id)", 
   "simple join clause";


$foo_id = { -type => 'identifier', elements => [qw/foo_id/] };

is $sqla->dispatch(
  { -type => 'join',
    lhs => $fnord,
    rhs => {-type => 'alias', ident => $foo, as => 'bar' },
    using => $foo_id
  }
), "fnord JOIN foo AS bar USING (foo_id)", 
   "using join clause";


is $sqla->dispatch(
  { -type => 'join',
    join_type => 'LEFT',
    lhs => $fnord,
    rhs => {-type => 'alias', ident => $foo, as => 'bar' },
    using => $foo_id
  }
), "fnord LEFT JOIN foo AS bar USING (foo_id)", 
   "using left join clause";
