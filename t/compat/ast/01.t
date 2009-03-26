use strict;
use warnings;

use SQL::Abstract::AST::Compat;

use Test::More tests => 6;
use Test::Differences;

ok(my $visitor = SQL::Abstract::AST::Compat->new);

my $foo_eq_1 = {
  -type => 'expr',
  op => '==',
  args => [
    { -type => 'name', args => [qw/foo/] }, 
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
    { -type => 'name', args => [qw/bar/] }, 
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
  "-and as first element of array";
