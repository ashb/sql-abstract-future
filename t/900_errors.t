use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

throws_ok {
  $sqla->dispatch(
    { -type => 'expr', op => '==',
      args => [
        { -type => 'name', args => [qw/me id/] },
        { -type => 'alias', ident => { -type => 'name', args => [qw/me id/] }, as => 'bar' }
      ]
    }
  )
} qr/^'alias' is not a valid AST type in an expression/, "Error from invalid part in where";

throws_ok {
  $sqla->dispatch(
    { -type => 'expr', op => '~' }
  )
} qr/^'~' is not a valid operator in an expression/

