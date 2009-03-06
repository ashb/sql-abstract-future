use strict;
use warnings;

use Test::More tests => 2;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

is $sqla->dispatch(
  [ -join =>
      [-name => qw/foo/],
      [ '==', [-name => qw/foo id/], [ -name => qw/me foo_id/ ] ]
  ]
), "JOIN foo ON (foo.id = me.foo_id)", 
   "simple join clause";

