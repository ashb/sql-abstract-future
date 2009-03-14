use MooseX::Declare;

class SQL::Abstract::AST::v1 extends SQL::Abstract {

  use Carp qw/croak/;
  use Data::Dump qw/pp/;

  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/ArrayRef Str Int Ref HashRef/;
  use MooseX::AttributeHelpers;
  use SQL::Abstract::Types qw/AST ArrayAST HashAST/;
  use Devel::PartialDump qw/dump/;

  clean;

  # set things that are valid in where clauses
  override _build_expr_dispatch_table {
    return { 
      %{super()},
      in => $self->can('_in'),
      not_in => $self->can('_in'),
      and => $self->can('_recurse_where'),
      or => $self->can('_recurse_where'),
      map { +"$_" => $self->can("_$_") } qw/
        value
        name
        true
        false
        expr
      /
    };
  }

  method _select(HashAST $ast) {
    # Default to requiring columns and from.
    # DB specific ones (i.e. mysql/Pg) can not require the FROM part with a bit
    # of refactoring
    
    for (qw/columns tablespec/) {
      confess "'$_' is required in select AST with " . dump ($ast)
        unless exists $ast->{$_};
    }
   
    # Check that columns is a -list
    confess "'columns' should be an array ref, not " . dump($ast->{columns})
      unless is_ArrayRef($ast->{columns});

    my $cols = $self->_list({-type => 'list', args => $ast->{columns} });

    my @output = (
      SELECT => $cols
    );

    push @output, FROM => $self->dispatch($ast->{tablespec})
      if exists $ast->{tablespec};

    for (qw//) {
      if (exists $ast->{$_}) {
        my $sub_ast = $ast->{$_};
        $sub_ast->{-type} = "$_" if is_HashRef($sub_ast);
        confess "$_ option is not an AST"
          unless is_AST($sub_ast);

        push @output, $self->dispatch($sub_ast);
      }
    }

    return join(' ', @output);
  }

  method _join(HashRef $ast) {
    confess "'args' option to join should be an array ref, not " . dump($ast->{args})
      unless is_ArrayRef($ast->{args});

    my ($from, $to) = @{ $ast->{args} };

    # TODO: Validate join type
    my $type = $ast->{join_type} || "";
  
    my @output = $self->dispatch($from);

    push @output, uc $type if $type;
    push @output, "JOIN", $self->dispatch($to);

    push @output, 
        exists $ast->{on}
      ? ('ON', '(' . $self->_expr( $ast->{on} ) . ')' )
      : ('USING', '(' .$self->dispatch($ast->{using} || croak "No 'on' or 'join' clause passed to -join").
                  ')' );

    return join(" ", @output);
      
  }

  method _order_by(AST $ast) {
    my @clauses = @{$ast->{order_by}};
  
    my @output;
   
    for (@clauses) {
      if (is_ArrayRef($_) && $_->[0] =~ /^-(asc|desc)$/) {
        my $o = $1;
        push @output, $self->dispatch($_->[1]) . " " . uc($o);
        next;
      }
      push @output, $self->dispatch($_);
    }

    return "ORDER BY " . join(", ", @output);
  }

  method _name(HashAST $ast) {
    my @names = @{$ast->{args}};

    my $sep = $self->name_separator;
    my $quote = $self->is_quoting 
              ? $self->quote_chars
              : [ '' ];

    my $join = $quote->[-1] . $sep . $quote->[0];

    # We dont want to quote * in [qw/me */]: `me`.* is the desired output there
    # This means you can't have a field called `*`. I am willing to accept this
    # situation, cos thats a really stupid thing to want.
    my $post;
    $post = pop @names if $names[-1] eq '*';

    my $ret = 
      $quote->[0] . 
      join( $join, @names ) . 
      $quote->[-1];

    $ret .= $sep . $post if defined $post;
    return $ret;
  }


  method _list(AST $ast) {
    my @items = @{$ast->{args}};

    return join(
      $self->list_separator,
      map { $self->dispatch($_) } @items);
  }

  # TODO: I think i want to parameterized AST type to get better validation
  method _alias(AST $ast) {
    
    # TODO: Maybe we want qq{ AS "$as"} here
    return $self->dispatch($ast->{ident}) . " AS " . $ast->{as};

  }

  method _value(HashAST $ast) {

    $self->add_bind($ast->{value});
    return "?";
  }

  # Perhaps badly named. handles 'and' and 'or' clauses
  method _recurse_where(HashAST $ast) {

    my $op = $ast->{op};

    my $OP = uc $op;
    my $prio = $SQL::Abstract::PRIO{$op};

    my $dispatch_table = $self->expr_dispatch_table;

    my @output;
    foreach ( @{$ast->{args}} ) {
      croak "invalid component in where clause: $_" unless is_HashAST($_);

      if ($_->{-type} eq 'expr' && $_->{op} =~ /^(and|or)$/) {
        my $sub_prio = $SQL::Abstract::PRIO{$1}; 

        if ($sub_prio <= $prio) {
          push @output, $self->_recurse_where($_);
        } else {
          push @output, '(' . $self->_recurse_where($_) . ')';
        }
      } else {
        push @output, $self->_expr($_);
      }
    }

    return join(" $OP ", @output);
  }

  method _expr(HashAST $ast) {
    my $op = $ast->{-type};

    $op = $ast->{op} if $op eq 'expr';

    if (my $code = $self->lookup_expr_dispatch($op)) { 
      
      return $code->($self, $ast);

    }
    croak "'$op' is not a valid AST type in an expression with " . dump($ast)
      if $ast->{-type} ne 'expr';

    croak "'$op' is not a valid operator in an expression with " . dump($ast);
   
  }

  method _binop(HashAST $ast) {
    my ($lhs, $rhs) = @{$ast->{args}};
    my $op = $ast->{op};

    join (' ', $self->_expr($lhs), 
               $self->binop_mapping($op) || croak("Unknown binary operator $op"),
               $self->_expr($rhs)
    );
  }

  method _in(HashAST $ast) {
  
    my ($field,@values) = @{$ast->{args}};

    my $not = ($ast->{op} =~ /^not_/) ? " NOT" : "";

    return $self->_false unless @values;

    return $self->_expr($field) .
           $not . 
           " IN (" .
           join(", ", map { $self->dispatch($_) } @values ) .
           ")";
  }

  method _generic_func(ArrayRef $ast) {
  }

  # 'constants' that are portable across DBs
  method _false($ast?) { "0 = 1" }
  method _true($ast?) { "1 = 1" }

}
