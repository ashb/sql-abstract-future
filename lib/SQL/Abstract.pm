use MooseX::Declare;
use MooseX::Method::Signatures;


class SQL::Abstract {

  use Carp qw/croak/;
  use Data::Dump qw/pp/;

  use Moose::Util::TypeConstraints;
  use MooseX::Types -declare => [qw/NameSeparator/];
  use MooseX::Types::Moose qw/ArrayRef Str/;
  use MooseX::AttributeHelpers;

  use namespace::clean -except => ['meta'];

  subtype NameSeparator,
    as ArrayRef[Str];
    #where { @$_ == 1 ||| @$_ == 2 },
    #message { "Name separator must be one or two elements" };

  coerce NameSeparator, from Str, via { [ $_ ] };

  our $VERSION = '2.000000';

  our $AST_VERSION = '1';

  # Operator precedence for bracketing
  our %PRIO = (
    and => 10,
    or  => 50
  );

  our %OP_MAP = (
    '>' => '>',
    '<' => '<',
    '==' => '=',
    '!=' => '!=',
  );

  has name_separator => ( 
    is => 'rw', 
    isa => NameSeparator,
    default => sub { ['.'] },
    coerece => 1,
    required => 1,
  );

  has list_separator => ( 
    is => 'rw', 
    isa => Str,
    default => ', ',
    required => 1,
  );

  has binds => (
    isa => ArrayRef,
    is => 'ro',
    default => sub { [ ] },
    metaclass => 'Collection::Array',
    provides => {
      push => 'add_bind',
      clear => '_clear_binds',
    }
  );

  method generate (Object|ClassName $self: ArrayRef $ast) {
    my $class_meth = !blessed($self);
    $self = $self->new if $class_meth;

    local $_ = $ast->[0];
    s/^-/_/g or croak "Unknown type tag '$_'";
    my $meth = $self->can($_) || \&_generic_func;
    return $class_meth
         ? ($meth->($self, $ast), $self->binds)
         : $meth->($self, $ast);
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
        push @output, $self->generate($_->[1]) . " " . uc($o);
        next;
      }
      push @output, $self->generate($_);
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

  method _list(ArrayRef $ast) {
    my (undef, @items) = @$ast;

    return join(
      $self->list_separator,
      map { $self->generate($_) } @items);
  }

  method _alias(ArrayRef $ast) {
    my (undef, $alias, $as) = @$ast;

    return $self->generate($alias) . " AS $as";

  }

  method _value(ArrayRef $ast) {
    my ($undef, $value) = @$ast;

    $self->add_bind($value);
    return "?";
  }

  method _recurse_where($clauses) {

    my $OP = 'AND';
    my $prio = $PRIO{and};
    my $first = $clauses->[0];

    if (!ref $first && $first =~ /^-(and|or)$/) {
      $OP = uc($1);
      $prio = $PRIO{$1};
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
        my $sub_prio = $PRIO{$1}; 

        if ($sub_prio <= $prio) {
          push @output, $self->_recurse_where($_);
        } else {
          push @output, '(' . $self->_recurse_where($_) . ')';
        }
      } else {
        push @output, $self->generate($_);
      }
    }

    return join(" $OP ", @output);
  }

  method _binop($op, $lhs, $rhs) {
    join (' ', $self->generate($lhs), 
               $OP_MAP{$op} || croak("Unknown binary operator $op"),
               $self->generate($rhs)
    );
  }

  method _generic_func(ArrayRef $ast) {
  }


};
