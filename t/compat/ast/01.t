use strict;
use warnings;

use SQL::Abstract::Compat;

use Test::More tests => 12;
use Test::Differences;

ok(my $visitor = SQL::Abstract::Compat->new);


my $foo_id = { -type => 'name', args => [qw/foo/] };
my $bar_id = { -type => 'name', args => [qw/bar/] };

my $foo_eq_1 = field_op_value($foo_id, '==', 1);
my $bar_eq_str = field_op_value($bar_id, '==', 'some str');

eq_or_diff
  $visitor->recurse_where({ foo => 1 }),
  $foo_eq_1,
  "Single value hash";



eq_or_diff
  $visitor->recurse_where({ foo => 1, bar => 'some str' }),
  { -type => 'expr',
    op => 'and',
    args => [
      $bar_eq_str,
      $foo_eq_1,
    ]
  },
  "two keys in hash";

eq_or_diff
  $visitor->recurse_where({ -or => { foo => 1, bar => 'some str' } }),
  { -type => 'expr',
    op => 'or',
    args => [
      $bar_eq_str,
      $foo_eq_1,
    ]
  },
  "-or key in hash";


eq_or_diff
  $visitor->recurse_where([ -and => { foo => 1, bar => 'some str' } ]),
  { -type => 'expr',
    op => 'and',
    args => [
      $bar_eq_str,
      $foo_eq_1,
    ]
  },
  "-and as first element of array";


eq_or_diff
  $visitor->recurse_where([ -and => { foo => 1, bar => 'some str' }, { foo => 1} ]),
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
  $visitor->recurse_where({ foo => { '!=' => 'bar' } }),
  field_op_value($foo_id, '!=', 'bar'),
  "foo => { '!=' => 'bar' }";

eq_or_diff
  $visitor->recurse_where({ foo => [ 1, 'bar' ] }),
  { -type => 'expr',
    op => 'or',
    args => [
      $foo_eq_1,
      field_op_value($foo_id, '==', 'bar'),
    ],
  },
  "foo => [ 1, 'bar' ]";

eq_or_diff
  $visitor->recurse_where({ foo => { -in => [ 1, 'bar' ] } }),
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
  $visitor->recurse_where({ foo => { -not_in => [ 1, 'bar' ] } }),
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
  $visitor->recurse_where({ foo => { -in => [ ] } }),
  { -type => 'expr',
    op => 'in',
    args => [
      $foo_id,
    ]
  },
  "foo => { -in => [ ] }";

my $worker_eq = sub {
  return { 
    -type => 'expr',
    op => '==',
    args => [
      { -type => 'name', args => ['worker'] },
      { -type => 'value', value => $_[0] },
    ],
  }
};
eq_or_diff
  $visitor->recurse_where( {
    requestor => 'inna',
    worker => ['nwiger', 'rcwe', 'sfz'],
    status => { '!=', 'completed' }
  } ),
  { -type => 'expr',
    op => 'and',
    args => [
      field_op_value(qw/status != completed/), 
      { -type => 'expr',
        op => 'or',
        args => [
          field_op_value(qw/worker == nwiger/), 
          field_op_value(qw/worker == rcwe/), 
          field_op_value(qw/worker == sfz/), 
        ]
      },
      field_op_value(qw/requestor == inna/),
    ]
  },
  "complex expr #1";



sub field_op_value {
  my ($field, $op, $value) = @_;

  $field = ref $field eq 'HASH'
         ? $field
         : ref $field eq 'ARRAY' 
         ? { -type => 'name', args => $field } 
         : { -type => 'name', args => [$field] };

  $value = ref $value eq 'HASH'
         ? $value
         : { -type => 'value', value => $value };

  return {
    -type => 'expr',
    op => $op,
    args => [
      $field,
      $value
    ]
  };
}
