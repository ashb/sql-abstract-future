use MooseX::Declare;

class SQL::Abstract::AST::v1 extends SQL::Abstract {

  use Carp qw/croak/;
  use Data::Dump qw/pp/;

  use Moose::Util::TypeConstraints;
  use MooseX::Types -declare => [qw/NameSeparator/];
  use MooseX::Types::Moose qw/ArrayRef Str Int/;
  use MooseX::AttributeHelpers;

  clean;

  method dispatch (ArrayRef $ast) {

    local $_ = $ast->[0];
    s/^-/_/g or croak "Unknown type tag '$_'";
    my $meth = $self->can($_) || \&_generic_func;
    return $meth->($self, $ast);
  }

  method _select(ArrayRef $ast) {
    
  }

  method _where(ArrayRef $ast) {
    my (undef, @clauses) = @$ast;
  
    return 'WHERE ' . $self->_recurse_where(\@clauses);
  }

  method _order_by(ArrayRef $ast) {
    my (undef, @clauses) = @$ast;

    my @output;
   
    for (@clauses) {
      if ($_->[0] =~ /^-(asc|desc)$/) {
        my $o = $1;
        push @output, $self->dispatch($_->[1]) . " " . uc($o);
        next;
      }
      push @output, $self->dispatch($_);
    }

    return "ORDER BY " . join(", ", @output);
  }

  method _name(ArrayRef $ast) {
    my (undef, @names) = @$ast;

    my $sep = $self->name_separator;

    return $sep->[0] . 
           join( $sep->[1] . $sep->[0], @names ) . 
           $sep->[1]
              if (@$sep > 1);

    return join($sep->[0], @names);
  }

  method _join(ArrayRef $ast) {
    
  }

  method _list(ArrayRef $ast) {
    my (undef, @items) = @$ast;

    return join(
      $self->list_separator,
      map { $self->dispatch($_) } @items);
  }

  method _alias(ArrayRef $ast) {
    my (undef, $alias, $as) = @$ast;

    return $self->dispatch($alias) . " AS $as";

  }

  method _value(ArrayRef $ast) {
    my ($undef, $value) = @$ast;

    $self->add_bind($value);
    return "?";
  }

  method _recurse_where($clauses) {

    my $OP = 'AND';
    my $prio = $SQL::Abstract::PRIO{and};
    my $first = $clauses->[0];

    if (!ref $first && $first =~ /^-(and|or)$/) {
      $OP = uc($1);
      $prio = $SQL::Abstract::PRIO{$1};
      shift @$clauses;
    }

    my @output;
    foreach (@$clauses) {
      croak "invalid component in where clause" unless ArrayRef->check($_);
      my $op = $_->[0];

      unless (substr($op, 0, 1) eq '-') {
        # A simple comparison op (==, >, etc.)
        
        push @output, $self->_binop(@$_);
        
      } elsif ($op =~ /^-(and|or)$/) {
        my $sub_prio = $SQL::Abstract::PRIO{$1}; 

        if ($sub_prio <= $prio) {
          push @output, $self->_recurse_where($_);
        } else {
          push @output, '(' . $self->_recurse_where($_) . ')';
        }
      } else {
        push @output, $self->dispatch($_);
      }
    }

    return join(" $OP ", @output);
  }

  method _binop($op, $lhs, $rhs) {
    join (' ', $self->dispatch($lhs), 
               $SQL::Abstract::OP_MAP{$op} || croak("Unknown binary operator $op"),
               $self->dispatch($rhs)
    );
  }

  method _in($ast) {
    my (undef, $field, @values) = @$ast;

    return $self->dispatch($field) .
           " IN (" .
           join(", ", map { $self->dispatch($_) } @values ) .
           ")";
  }

  method _generic_func(ArrayRef $ast) {
  }

}
