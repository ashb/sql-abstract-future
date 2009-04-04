use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;

use_ok('SQL::Abstract') or BAIL_OUT( "$@" );

my $sqla = SQL::Abstract->create(1);

throws_ok {
  $sqla->dispatch(
    { -type => 'expr', op => '==',
      args => [
        { -type => 'identifier', elements => [qw/me id/] },
        { -type => 'alias', ident => { -type => 'identifier', elements => [qw/me id/] }, as => 'bar' }
      ]
    }
  )
} qr/^'alias' is not a valid AST type in an expression/, "Error from invalid part in where";

throws_ok {
  $sqla->dispatch(
    { -type => 'expr', op => '~' }
  )
} qr/^'~' is not a valid operator in an expression/;

local $TODO = "Work out how to get nice errors for these";

throws_ok {
  $sqla->dispatch(
    { -type => 'alias', ident => 2 } # no as, inavlid ident
  )
} qr/foobar/, "alias: no as, invalid ident";

throws_ok {
  $sqla->dispatch(
    { -type => 'alias', iden => { -type => 'identifier', elements => ['id'] }, as => 'foo' } # iden not ident
  )
} qr/foobar/, "alias: iden instead of ident";

