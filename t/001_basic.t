use strict;
use warnings;

use Test::More tests => 9;
use Test::Differences;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );
use_ok('SQL::Abstract::AST::v1') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

# TODO: once MXMS supports %args, use that here
is $sqla->dispatch( { -type => 'name', args => [qw/me id/] }), "me.id",
  "Simple name generator";

is $sqla->dispatch( { -type => 'name', args => [qw/me */]}),
   "me.*",
   "Simple name generator";

$sqla->quote_chars(['`']);

is $sqla->dispatch( { -type => 'name', args => [qw/me */]}),
   "`me`.*",
   "Simple name generator";

$sqla->disable_quoting;

is $sqla->dispatch(
  { -type => 'false' }
), "0 = 1", "false value";

is $sqla->dispatch(
  { -type => 'true' }
), "1 = 1", "true value";

is $sqla->dispatch(
  { -type => 'list',
    args => [
      { -type => name => args => [qw/me id/] },
      { -type => name => args => [qw/me foo bar/] },
      { -type => name => args => [qw/bar/] }
    ] 
  }
), "me.id, me.foo.bar, bar",
  "List generator";

is $sqla->dispatch(
  { -type => 'alias', ident => { -type => name => args => [qw/me id/]}, as => "foobar" } 
), "me.id AS foobar",
  "Alias generator";


