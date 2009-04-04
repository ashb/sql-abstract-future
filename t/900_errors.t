use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/lib";
use Test::SQL::Abstract::Util qw/
  mk_name
  mk_value
  mk_alias
/;

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

{
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

}

throws_ok {
  $sqla->dispatch(
    { -type => 'update',
      tablespec => mk_name('test'),
      columns => [
        mk_name(qw/me id/),
        mk_alias(mk_name(qw/foo id/) ,'foo_id')
      ]
    }
  )
} qr/^'values' is required in update AST/, "Invalid clause in update"
