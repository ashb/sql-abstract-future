use strict;
use warnings;

use Test::More tests => 5;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

is SQL::Abstract->generate( [ -name => qw/me id/]), "me.id",
  "Simple name generator";

is SQL::Abstract->generate(
  [ -list => 
    [ -name => qw/me id/],
    [ -name => qw/me foo bar/],
    [ -name => qw/bar/]
  ] 
), "me.id, me.foo.bar, bar",
  "List generator";

is SQL::Abstract->generate(
  [ -alias => [ -name => qw/me id/], "foobar", ] 
), "me.id AS foobar",
  "Alias generator";

is SQL::Abstract->generate(
  [ -where =>
      [ '>', [-name => qw/me.id/], [-value => 500 ] ]
  ]
), "WHERE me.id > ?", "where clause";
