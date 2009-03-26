use MooseX::Declare;

class SQL::Abstract::AST::Compat {

  use MooseX::Types::Moose qw/ArrayRef HashRef Str ScalarRef/;
  use SQL::Abstract::Types qw/AST/;
  use SQL::Abstract::Types::Compat ':all';
  use Devel::PartialDump qw/dump/;
  use Carp qw/croak/;

  clean;

  has logic => (
    is => 'rw',
    isa => LogicEnum,
    default => 'AND'
  );

  method generate(WhereType $ast) returns (AST) {
    return $self->recurse_where($ast);
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
    my $ret = {
      -type => 'expr',
      op => '==',
      args => [
        { -type => 'name', args => [$key] }
      ],
    };

    if (is_Str($value)) {
      push @{$ret->{args}}, { -type => 'value', value => $value };
    }

    return $ret;
  }


};

1;

=head1 NAME

SQL::Abstract::AST::Compat - v1.xx AST -> v2 AST visitor

=head1 DESCRIPTION

The purpose of this module is to take the where clause arguments from version
1.x of SQL::Abstract, and turn it into a proper, explicit AST, suitable for use
in the rest of the code.

Please note that this module does not have the same interface as other
SQL::Abstract ASTs.

=head1 AUTHOR

Ash Berlin C<< <ash@cpan.org> >>

=cut
