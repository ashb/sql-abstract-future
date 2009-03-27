use strict;
use warnings;

use SQL::Abstract::AST::Compat;

use Test::More tests => 11;
use Test::Differences;

ok(my $visitor = SQL::Abstract::AST::Compat->new);

my $foo_id = { -type => 'name', args => [qw/foo/] };
my $bar_id = { -type => 'name', args => [qw/bar/] };

my $foo_eq_1 = {
  -type => 'expr',
  op => '==',
  args => [
    $foo_id,
    { -type => 'value', value => 1 }
  ]
};

eq_or_diff
  $visitor->generate({ foo => 1 }),
  $foo_eq_1,
  "Single value hash";


my $bar_eq_str = {
  -type => 'expr',
  op => '==',
  args => [
    $bar_id,
    { -type => 'value', value => 'some str' }
  ]
};

eq_or_diff
  $visitor->generate({ foo => 1, bar => 'some str' }),
  { -type => 'expr',
    op => 'and',
    args => [
      $bar_eq_str,
      $foo_eq_1,
    ]
  },
  "two keys in hash";

eq_or_diff
  $visitor->generate({ -or => { foo => 1, bar => 'some str' } }),
  { -type => 'expr',
    op => 'or',
    args => [
      $bar_eq_str,
      $foo_eq_1,
    ]
  },
  "-or key in hash";


eq_or_diff
  $visitor->generate([ -and => { foo => 1, bar => 'some str' } ]),
  { -type => 'expr',
    op => 'and',
    args => [
      $bar_eq_str,
      $foo_eq_1,
    ]
  },
  "-and as first element of array";


eq_or_diff
  $visitor->generate([ -and => { foo => 1, bar => 'some str' }, { foo => 1} ]),
  { -type => 'expr',
    op => 'or',
    args => [
      { -type => 'expr',
        op => 'and',
        args => [
          $bar_eq_str,
          $foo_eq_1,
        ]
      },
      $foo_eq_1,
    ]
  },
  "-and as first element of array + hash";

eq_or_diff
  $visitor->generate({ foo => { '!=' => 'bar' } }),
  { -type => 'expr',
    op => '!=',
    args => [
      $foo_id,
      { -type => 'value', value => 'bar' },
    ]
  },
  "foo => { '!=' => 'bar' }";

eq_or_diff
  $visitor->generate({ foo => [ 1, 'bar' ] }),
  { -type => 'expr',
    op => 'or',
    args => [
      $foo_eq_1,
      { -type => 'expr',
        op => '==',
        args => [
          $foo_id,
          { -type => 'value', value => 'bar' },
        ]
      },
    ],
  },
  "foo => [ 1, 'bar' ]";

eq_or_diff
  $visitor->generate({ foo => { -in => [ 1, 'bar' ] } }),
  { -type => 'expr',
    op => 'in',
    args => [
      $foo_id,
      { -type => 'value', value => 1 },
      { -type => 'value', value => 'bar' },
    ]
  },
  "foo => { -in => [ 1, 'bar' ] }";

eq_or_diff
  $visitor->generate({ foo => { -not_in => [ 1, 'bar' ] } }),
  { -type => 'expr',
    op => 'not_in',
    args => [
      $foo_id,
      { -type => 'value', value => 1 },
      { -type => 'value', value => 'bar' },
    ]
  },
  "foo => { -not_in => [ 1, 'bar' ] }";

eq_or_diff
  $visitor->generate({ foo => { -in => [ ] } }),
  { -type => 'expr',
    op => 'in',
    args => [
      $foo_id,
    ]
  },
  "foo => { -in => [ ] }";

