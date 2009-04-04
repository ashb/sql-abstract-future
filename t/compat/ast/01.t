use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";
use SQLADumperSort;

use SQL::Abstract::Compat;

use Test::More tests => 17;
use Test::Differences;

ok(my $visitor = SQL::Abstract::Compat->new);


my $foo_id = { -type => 'identifier', elements => [qw/foo/] };
my $bar_id = { -type => 'identifier', elements => [qw/bar/] };

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
      { -type => 'identifier', elements => ['worker'] },
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
      field_op_value(qw/requestor == inna/),
      field_op_value(qw/status != completed/), 
      { -type => 'expr',
        op => 'or',
        args => [
          field_op_value(qw/worker == nwiger/), 
          field_op_value(qw/worker == rcwe/), 
          field_op_value(qw/worker == sfz/), 
        ]
      },
    ]
  },
  "complex expr 1";


$visitor->convert('UPPER');

my $ticket_or_eq = { 
  -type => 'expr', 
  op => 'or',
  args => [
    field_op_value( upper(mk_name('ticket')), '==', upper(mk_value(11))),
    field_op_value( upper(mk_name('ticket')), '==', upper(mk_value(12))),
    field_op_value( upper(mk_name('ticket')), '==', upper(mk_value(13))),
  ] 
};

eq_or_diff
  $visitor->select_ast(
    'test', '*', [ { ticket => [11, 12, 13] } ]
  ),
  { -type => 'select',
    columns => [ { -type => 'identifier', elements => ['*'] } ],
    tablespec => { -type => 'identifier', elements => ['test'] },
    where => $ticket_or_eq
  },
  "Complex AST with convert('UPPER')";

my $hostname_and_ticket = {
  -type => 'expr',
  op => 'and',
  args => [
    field_op_value( upper(mk_name('hostname')),
                    in => [ map {
                      upper(mk_value($_))
                    } qw/ntf avd bvd 123/ ]
                  ),
    $ticket_or_eq,
  ]
};

eq_or_diff
  $visitor->select_ast(
    'test', '*', [ { ticket => [11, 12, 13],
                     hostname => { in => ['ntf', 'avd', 'bvd', '123'] }
                   }
                 ]
  ),
  { -type => 'select',
    columns => [ { -type => 'identifier', elements => ['*'] } ],
    tablespec => { -type => 'identifier', elements => ['test'] },
    where => $hostname_and_ticket
  },
  "Complex AST mixing arrays+hashes with convert('UPPER')";

my $tack_between = {
  -type => 'expr',
  op => 'between',
  args => [
    upper(mk_name('tack')),
    upper(mk_value('tick')),
    upper(mk_value('tock')),
  ]
};

eq_or_diff
  $visitor->select_ast(
    'test', '*', [ { ticket => [11, 12, 13],
                     hostname => { in => ['ntf', 'avd', 'bvd', '123'] }
                   },
                   { tack => { between => [qw/tick tock/] } }
                 ]
  ),
  { -type => 'select',
    columns => [ { -type => 'identifier', elements => ['*'] } ],
    tablespec => { -type => 'identifier', elements => ['test'] },
    where => {
      -type => 'expr',
      op => 'or',
      args => [
        $hostname_and_ticket,
        $tack_between,
      ]
    }
  },
  "Complex AST mixing [ {a => [1,2],b => 3}, { c => 4 }]";

my $a_or_eq = {
 -type => 'expr',
 op => 'or',
 args => [ map {
  { -type => 'expr', op => '==', args => [ upper(mk_name('a')), upper(mk_value($_)) ] }
 } qw/b c d/ ]
};

my $e_ne = {
 -type => 'expr',
 op => 'or',
 args => [ map {
  { -type => 'expr', op => '!=', args => [ upper(mk_name('e')), upper(mk_value($_)) ] }
 } qw/f g/ ]
};

eq_or_diff
  $visitor->select_ast(
    'test', '*', [ { ticket => [11, 12, 13],
                     hostname => { in => ['ntf', 'avd', 'bvd', '123'] }
                   },
                   { tack => { between => [qw/tick tock/] } },
                   { a => [qw/b c d/], 
                     e => { '!=', [qw(f g)] }, 
                   }
                 ]
  ),
  { -type => 'select',
    columns => [ { -type => 'identifier', elements => ['*'] } ],
    tablespec => { -type => 'identifier', elements => ['test'] },
    where => {
      -type => 'expr',
      op => 'or',
      args => [
        $hostname_and_ticket,
        $tack_between,
        { -type => 'expr', op => 'and', args => [ $a_or_eq, $e_ne ] }
      ]
    }
  },
  "Complex AST mixing [ {a => [1,2],b => 3}, { c => 4 }, { d => [5,6,7], e => { '!=' => [8,9] } } ]";


eq_or_diff
  $visitor->select_ast(
    'test', '*', [ { ticket => [11, 12, 13], 
                     hostname => { in => ['ntf', 'avd', 'bvd', '123'] } },
                  { tack => { between => [qw/tick tock/] } },
                  { a => [qw/b c d/], 
                    e => { '!=', [qw(f g)] }, 
                    q => { 'not in', [14..20] } 
                  }
                 ]
  ),
  { -type => 'select',
    columns => [ { -type => 'identifier', elements => ['*'] } ],
    tablespec => { -type => 'identifier', elements => ['test'] },
    where => {
      -type => 'expr',
      op => 'or',
      args => [
        $hostname_and_ticket,
        $tack_between,
        { -type => 'expr', op => 'and', args => [ 
          $a_or_eq, 
          $e_ne,
          { -type => 'expr',
            op => 'not_in',
            args => [
              upper(mk_name('q')),
              map { upper(mk_value($_)) } 14..20
            ]
          }
        ] }
      ]
    }
  },
  "Complex AST [ {a => [1,2],b => 3}, { c => 4 }, { d => [5,6,7], e => { '!=' => [8,9] }, q => {'not in' => [10,11] } } ]";

sub field_op_value {
  my ($field, $op, $value) = @_;

  $field = ref $field eq 'HASH'
         ? $field
         : ref $field eq 'ARRAY' 
         ? { -type => 'identifier', elements => $field } 
         : { -type => 'identifier', elements => [$field] };

  my @value = ref $value eq 'HASH'
            ? $value
            : ref $value eq 'ARRAY'
            ? @$value
            : { -type => 'value', value => $value };

  return {
    -type => 'expr',
    op => $op,
    args => [
      $field,
      @value
    ]
  };
}

sub upper { expr(UPPER => @_) }

sub expr {
  my ($op, @args) = @_;

  return {
    -type => 'expr',
    op => $op,
    args => [@args]
  };
}

sub mk_name {
  my ($field) = @_;
  $field = ref $field eq 'HASH'
         ? $field
         : ref $field eq 'ARRAY' 
         ? { -type => 'identifier', elements => $field } 
         : { -type => 'identifier', elements => [$field] };
  return $field;
}

sub mk_value {
  return { -type => 'value', value => $_[0] }
}
