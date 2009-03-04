use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

throws_ok {
  $sqla->dispatch(
    [ -where => 
      [ '==', [-name => qw/me id/], [ -alias => [-name => qw/me foo/], 'bar' ] ]
    ]
  )
} qr/^'-alias' is not a valid clause in a where AST/, "Error from invalid part in where";

throws_ok {
  $sqla->dispatch(
    [ -where => 
      [ '~', [-name => qw/me id/], [ -alias => [-name => qw/me foo/], 'bar' ] ]
    ]
  )
} qr/^'~' is not a valid operator/, 
  "Error from invalid operator in where";
