package Test::SQL::Abstract::Util;

use strict;
use warnings;

use Sub::Exporter -setup => {
  exports => [qw/
    mk_name
    mk_value
    mk_alias
    mk_expr
    field_op_value
  /],
  groups => [
    dumper_sort => sub {

      require Data::Dumper;
      my $Dump = Data::Dumper->can('Dump');

      no warnings 'redefine';

      *Data::Dumper::Dump = sub {
        local $Data::Dumper::Sortkeys = sub {
          my $hash = $_[0];
          my @keys = sort {
            my $a_minus = substr($a,0,1) eq '-';
            my $b_minus = substr($b,0,1) eq '-';

            return $a cmp $b if $a_minus || $b_minus;

            return -1 if $a eq 'op';
            return  1 if $b eq 'op';
            return $a cmp $b;
          } keys %$hash;

          return \@keys;
        };
        return $Dump->(@_);
      };
      return {};
    }
  ],
};

sub mk_alias {
  return {
    -type => 'alias',
    ident => shift,
    as    => shift,
  };
}

sub mk_name {
  my ($field) = shift;
  $field = ref $field eq 'HASH'
         ? $field
         : ref $field eq 'ARRAY'
         ? { -type => 'identifier', elements => $field }
         : { -type => 'identifier', elements => [$field,@_] };
  return $field;
}

sub mk_value {
  return { -type => 'value', value => $_[0] }
}

sub mk_expr {
  my ($op, @args) = @_;

  return {
    -type => 'expr',
    op => $op,
    args => [@args]
  };
}

sub field_op_value {
  my ($field, $op, $value) = @_;

  $field = ref $field eq 'HASH'
         ? $field
         : mk_name($field);

  my @value = ref $value eq 'HASH'
            ? $value
            : ref $value eq 'ARRAY'
            ? @$value
            : mk_value($value);

  return {
    -type => 'expr',
    op => $op,
    args => [
      $field,
      @value
    ]
  };
}

1;
