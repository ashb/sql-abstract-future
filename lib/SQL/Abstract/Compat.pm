use MooseX::Declare;

class SQL::Abstract::Compat {

  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/Str ScalarRef ArrayRef HashRef/;
  use SQL::Abstract::Types::Compat ':all';
  use SQL::Abstract::Types qw/AST/;
  use SQL::Abstract::AST::v1;
  use Data::Dump qw/pp/;
  use Devel::PartialDump qw/dump/;
  use Carp qw/croak/;

  class_type 'SQL::Abstract';
  clean;

  has logic => (
    is => 'rw',
    isa => LogicEnum,
    default => 'AND',
    coerce => 1,
    required => 1,
  );

  has visitor => (
    is => 'rw',
    isa => 'SQL::Abstract',
    clearer => 'clear_visitor',
    lazy => 1,
    builder => '_build_visitor',
  );

  has cmp => (
    is => 'rw',
    isa => 'Str',
    default => '=',
    required => 1,
  );

  our %CMP_MAP = (
    '=' => '==',
  );

  has convert => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_field_convertor'
  );

  method select(Str|ArrayRef|ScalarRef $from, ArrayRef|Str $fields,
                WhereType $where?,
                WhereType $order?)
  {
    my $ast = {
      -type => 'select',
      columns => [ 
        map {
          $self->mk_name(0, $_)
        } ( is_Str($fields) ? $fields : @$fields )
      ],
      tablespec => $self->tablespec($from)
    };


    $ast->{where} = $self->recurse_where($where)
      if defined $where;

    return ($self->visitor->dispatch($ast), $self->visitor->binds);
  }

  method where(WhereType $where,
               WhereType $order?)
  {
    my $ret = "";
 
    if ($where) {
      my $ast = $self->recurse_where($where);
      $ret .= "WHERE " . $self->visitor->_expr($ast);
    }

    return $ret;
  }

  method _build_visitor() {
    return SQL::Abstract->create(1);
  } 

  sub mk_name {
    my ($self, $use_convert) = (shift,shift);
    my $ast = { -type => 'name', args => [ @_ ] };

    return $ast
      unless $use_convert && $self->has_field_convertor;

    return $self->apply_convert($ast);
  }

  method tablespec(Str|ArrayRef|ScalarRef $from) {
    return $self->mk_name(0, $from)
      if is_Str($from);
  }

  method recurse_where(WhereType $ast, LogicEnum $logic?) returns (AST) {
    return $self->recurse_where_hash($logic || 'AND', $ast) if is_HashRef($ast);
    return $self->recurse_where_array($logic || 'OR', $ast) if is_ArrayRef($ast);
    croak "Unknown where clause type " . dump($ast);
  }

  method recurse_where_hash(LogicEnum $logic, HashRef $ast) returns (AST) {
    my @args;
    my $ret = {
      -type => 'expr',
      op => lc $logic,
      args => \@args
    };

    while (my ($key,$value) = each %$ast) {
      if ($key =~ /^-(or|and)$/) {
        my $val = $self->recurse_where($value, uc $1);
        if ($val->{op} eq $ret->{op}) {
          push @args, @{$val->{args}};
        }
        else {
          push @args, $val;
        }
        next;
      }

      push @args, $self->field($key, $value);
    }

    return $args[0] if @args == 1;

    return $ret;
  }

  method recurse_where_array(LogicEnum $logic, ArrayRef $ast) returns (AST) {
    my @args;
    my $ret = {
      -type => 'expr',
      op => lc $logic,
      args => \@args
    };
    my @nodes = @$ast;

    while (my $key = shift @nodes) {
      if ($key =~ /^-(or|and)$/) {
        my $value = shift @nodes
          or confess "missing value after $key at " . dump($ast);

        my $val = $self->recurse_where($value, uc $1);
        if ($val->{op} eq $ret->{op}) {
          push @args, @{$val->{args}};
        }
        else {
          push @args, $val;
        }
        next;
      }

      push @args, $self->recurse_where($key);
    }

    return $args[0] if @args == 1;

    return $ret;
  }

  method field(Str $key, $value) returns (AST) {
    my $op = $CMP_MAP{$self->cmp} || $self->cmp;
    my $ret = {
      -type => 'expr',
      op => $op,
      args => [
        $self->mk_name(1, $key)
      ],
    };

    if (is_HashRef($value)) {
      my ($op, @rest) = keys %$value;
      confess "Don't know how to handle " . dump($value) . " (too many keys)"
        if @rest;

      # TODO: Validate the op?
      if ($op =~ /^-([a-z_]+)$/i) {
        $ret->{op} = lc $1;

        if (is_ArrayRef($value->{$op})) {
          push @{$ret->{args}}, $self->value($_)
            for @{$value->{$op}};
          return $ret;
        }
      }
      else {
        $ret->{op} = $op;
      }

      push @{$ret->{args}}, $self->value($value->{$op});

    }
    elsif (is_ArrayRef($value)) {
      # Return an or clause, sort of.
      return {
        -type => 'expr',
        op => 'or',
        args => [ map {
          {
            -type => 'expr',
            op => $op,
            args => [
              { -type => 'name', args => [$key] },
              $self->value($_)
            ],
          }
        } @$value ]
      };
    }
    else {
      push @{$ret->{args}}, $self->value($value);
    }

    return $ret;
  }

  method value($value) returns (AST) {
    return $self->apply_convert( { -type => 'value', value => $value })
      if is_Str($value);

    confess "Don't know how to handle terminal value " . dump($value);
  }

  method apply_convert(AST $ast) {
    return $ast unless $self->has_field_convertor;

    return {
      -type => 'expr',
      op => $self->convert,
      args => [ $ast ]
    };
  }


}

=head1 NAME

SQL::Abstract::Compant - compatibility layer for SQL::Abstrct v 1.xx

=head1 DESCRIPTION

This class attempts to maintain the original behaviour of version 1 of
SQL::Abstract. It does this by internally converting to an AST and then using
the standard AST visitor.

If so desired, you can get hold of this transformed AST somehow. This is aimed
at libraries such as L<DBIx::Class> that use SQL::Abstract-style arrays or
hashes as part of their public interface.

=head1 AUTHOR

Ash Berlin C<< <ash@cpan.org> >>

=cut

1;
