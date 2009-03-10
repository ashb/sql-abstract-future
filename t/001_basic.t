use strict;
use warnings;

use Test::More tests => 11;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

# TODO: once MXMS supports %args, use that here
is $sqla->dispatch( [ -name => qw/me id/]), "me.id",
  "Simple name generator";

is $sqla->dispatch( [ -name => qw/me */]), 
   "me.*",
   "Simple name generator";

$sqla->quote_chars(['`']);

is $sqla->dispatch( [ -name => qw/me */]), 
   "`me`.*",
   "Simple name generator";

$sqla->disable_quoting;

is $sqla->dispatch(
  [ '-false' ]
), "0 = 1", "false value";

is $sqla->dispatch(
  [ '-true' ]
), "1 = 1", "true value";

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
), "ORDER BY me.date",
   "order by";

is $sqla->dispatch(
  [ -order_by => 
    [ -name => qw/me date/ ],
    [ -name => qw/me foobar/ ],
  ]
), "ORDER BY me.date, me.foobar",
   "order by";

is $sqla->dispatch(
  [ -order_by => [ -desc => [ -name => qw/me date/ ] ] ]
), "ORDER BY me.date DESC",
   "order by desc";


