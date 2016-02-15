#!/usr/bin/env perl6

use v6;

use NativeCall;

sub i2f(int64) returns num64 is native("aliaser", v1) { * }
sub f2i(num64) returns int64 is native("aliaser", v1) { * }

sub trace($x) {
  say $x;
  return $x;
}

my $U = "\e[1m\e[30mU\e[0m";

grammar U {
  token TOP { ^ <statements> $ }
  token statements {
    [<statement>? <sep>]* <statement>?
  }
  token number { 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 }
  token num-identifier { <[ a .. z ]> | ' ' }
  token list-identifier { L (..) }
  token func-identifier { Y (..) }
  token block-identifier { '"' (<[ -" ]>*) '"' }
  token ans { '_' }
  token ten { X }
  token identifier {
    <num-identifier> | <list-identifier> |
    <func-identifier> | <block-identifier>
  }
  token lvalue {
    [ <list-identifier> <expression>? ] |
    <identifier> |
    [ '*' | <expression> ]
  }
  token sep { \v | ':' }
  token cflow {
    [ $<keyword> = [ '?' | '?@!' | '?@' ] <cond=.expression> <sep> <body=.expression>] |
    [ $<keyword> = [ '?!' ] <cond=.expression> <sep> <tbody=.expression> <fbody=.expression> ]
  }
  token intrinsicStatement {
    $<keyword> = [ A | B | 'C>' | 'C<' | 'C+' | 'C-' | 'S+' | 'S~' | 'S.' ] <expression>
  }
  token assignment {
    <expression> ['~' <lvalue>]?
  }
  token statement {
    <intrinsicStatement> |
    <cflow> |
    <assignment>
  }
  token block {
    '{' <body=.statements> '}'
  }
  token function {
    \' <retval=.expression> \'
  }
  token symname {
    '@' <identifier>
  }
  # Lower-numbered precedence levels are stronger.
  token pl0 {
    # TODO: support dropping opening parens
    <ans> | <ten> | <number> | <identifier> |
    <block> | <function> | <symname> |
    [ '(' <expression> ')'? ] # | [ <expression> ')' ]
  }
  token pl1 {
    [ $<op> = <[ * P T ]> <pl1> ] |
    [ <pl0> $<op> = <[ F I ]>? ]
  }
  token pl2 {
    [ <left=.pl1> $<op> = <[ O U ]> <right=.pl1> ] | <pl1>
  }
  token pl3 {
    [ <pl2> [ $<op> = [ '^' | '.^' ] <pl2> ]* ]
  }
  token beo {
    ( <[ # $ ]>+ ) ( '^'? )
  }
  token pl4 {
    [ <pl3> [ $<op> = [ '/' | './' | '.*' | '+<' | '+>' | '+<^' | '+>^' ]? <pl3> ]* ]
  }
  token pl4h {
    [ <left=.pl4> [ <beo> <right=.pl4> ]? ]
  }
  token pl5 {
    [ <pl4h> [ $<op> = [ '+' | '-' | '.+' | '.-' ] <pl4h> ]* ]
  }
  token pl6 {
    [ <pl5> [ $<op> = [ '=' | '<' | '>' | '.=' | '.<' | '.>' ] <pl5> ]* ]
  }
  token pl7 {
    $<op> = [ '!' | '+-' ]? <pl6>
  }
  token pl8 {
    [ <pl7> [ $<op> = [ '&' | '|' | Q | '+&' | '+|' | '+Q' ] <pl7> ]* ]
  }
  token pl9 {
    [ <pl8> [ ',' <pl8> ]* ( ','? ) ]
  }
  token pl10 {
    [ $<op> = [ 'R+' | 'R~' | 'R~~' | 'R.' | [ D (<[ ~ + . ]>) ** 2 ] ]? <pl9> ]
  }
  token expression {
    <pl10>
  }
}

enum ASTType <Digit Name Ans LIndex LDeref If IfElse While Repeat IntrinsicStatement Assign Block Function Deref Pred Succ I2F F2I Trig Hyp TT FTT BI Div FDiv Mul FMul RL RR ShL ShR Add FAdd Subt FSubt BAnd BOr BXor Eq Lt Gt FEq FLt FGt Not BNot And Or Xor ListOf ReadInt ReadChars ReadLine ReadFloat Convert>;
enum DataTypes <DInt DFloat DList>;

class Uctions {
  method TOP($/) {
    $/.make: $<statements>.made;
  }
  method statements($/) {
    $/.make: $<statement>».made;
  }
  method number($/) {
    $/.make: [Digit, +$/];
  }
  method num-identifier($/) {
    my @sls = ords ~$/;
    $/.make: [Name, @sls[0] == 32 ?? 26 !! @sls[0] - 97];
  }
  method list-identifier($/) {
    my @sls = ords ~$0;
    $/.make: [Name, 96 * (@sls[0] - 32) + @sls[1]];
  }
  method func-identifier($/) {
    my @sls = ords ~$0;
    $/.make: [Name, 96 * (@sls[0] - 32) + @sls[1] + 32 * 96];
  }
  method block-identifier($/) {
    $/.make: [Name, ~$0];
  }
  method ans($/) {
    $/.make: Ans;
  }
  method ten($/) {
    $/.make: [Digit, 10];
  }
  method identifier($/) {
    $/.make: $<num-identifier>.made // $<list-identifier>.made //
      $<func-identifier>.made // $<block-identifier>.made;
  }
  method lvalue($/) {
    if ($<list-identifier>.defined) { return $/.make: [LIndex, $<list-identifier>.made, $<expression>.made]; }
    if ($<identifier>.defined) { return $/.make: $<identifier>.made; }
    return $/.make: [LDeref, $<expression>.made];
  }
  method sep($/) {
    return "What the heck are $U doing?!!";
  }
  method cflow($/) {
    given $<keyword> {
      when '?' { $/.make: [If, $<cond>.made, $<body>.made] }
      when '?!' { $/.make: [IfElse, $<cond>.made, $<tbody>.made, $<fbody>.made] }
      when '?@' { $/.make: [While, $<cond>.made, $<body>.made] }
      when '?@!' { $/.make: [Repeat, $<cond>.made, $<body>.made] }
    }
  }
  method intrinsicStatement($/) {
    $/.make: [IntrinsicStatement, ~$<keyword>, $<expression>.made];
  }
  method assignment($/) {
    return $/.make: [Assign, $<lvalue>.made, $<expression>.made] if $<lvalue>;
    return $/.make: $<expression>.made;
  }
  method statement($/) {
    $/.make: $<intrinsicStatement>.made // $<cflow>.made // $<assignment>.made;
  }
  method block($/) {
    $/.make: [Block, $<body>.made];
  }
  method function($/) {
    $/.make: [Function, $<retval>.made];
  }
  method synname($/) {
    $/.make: [Digit, $<identifier>.made];
  }
  method pl0($/) {
    $/.make: $<ans>.made // $<ten>.made // $<number>.made // $<identifier>.made //
      $<block>.made // $<function>.made // $<symname>.made //
      $<expression>.made;
  }
  method pl1($/) {
    my %lut =
      '*' => Deref,
      :P(Pred),
      :T(Succ),
      :F(I2F),
      :I(F2I);
    return $/.make: $<pl0>.made if !~$<op>;
    $/.make: [%lut{$<op>}, $<pl0>.made // $<pl1>.made];
  }
  method pl2($/) {
    if $<op>.defined {
      return $/.make: [
        $<op> eq 'O' ?? Trig !! Hyp,
        $<left>.made, $<right>.made
      ];
    }
    $/.make: $<pl1>.made;
  }
  sub tumbleRight($/, $operandName, %table, $start = 0) {
    my $count = $<op>.elems;
    if $start == $count {
      return $/.make: $/{$operandName}[$start].made;
    }
    return $/.make: [
      %table{$<op>[$start]},
      $/{$operandName}[$start].made,
      tumbleRight($/, $operandName, %table, $start + 1)
    ];
  }
  sub tumbleLeft($/, $operandName, %table, $e?) {
    my $count = $<op>.elems;
    my $end = $e // $count;
    if $end == 0 {
      return $/.make: $/{$operandName}[0].made;
    }
    return $/.make: [
      %table{$<op>[$end - 1]},
      tumbleLeft($/, $operandName, %table, $end - 1),
      $/{$operandName}[$end].made
    ];
  }
  sub tumbleLeftF($/, $operandName, &cb, $e?) {
    my $count = $<op>.elems;
    my $end = $e // $count;
    if $end == 0 {
      return $/.make: $/{$operandName}[0].made;
    }
    return cb(
      $/,
      $<op>[$end - 1],
      tumbleLeftF($/, $operandName, &cb, $end - 1),
      $/{$operandName}[$end].made
    );
  }
  method pl3($/) {
    my %table =
      "^" => TT,
      ".^" => FTT;
    tumbleRight($/, "pl2", %table);
  }
  method beo($/) {
    given ~$0 {
      $/.make: [
        (8 * m:global/'$'/.elems + 9 * m:global/'#'/.elems) +& 63,
        ?$1
      ];
    }
  }
  method pl4($/) {
    my %table =
      "/" => Div,
      "./" => FDiv,
      "" => Mul,
      ".*" => FMul,
      "+<" => RL,
      "+>" => RR,
      "+<^" => ShL,
      "+>^" => ShR;
    tumbleLeft($/, "pl3", %table);
  }
  method pl4h($/) {
    if $<beo>.defined {
      my @res = $/.make: $<beo>.made;
      $/.make: [BI, @res[0], @res[1], $<left>.made, $<right>.made];
    } else {
      $/.make: $<left>.made;
    }
  }
  method pl5($/) {
    my %table =
      "+" => Add,
      ".+" => FAdd,
      "-" => Subt,
      ".-" => FSubt;
    tumbleLeft($/, "pl4h", %table);
  }
  method pl6($/) {
    my %table =
      "=" => Eq,
      "<" => Lt,
      ">" => Gt,
      ".=" => FEq,
      ".<" => FLt,
      ".>" => FGt;
    tumbleLeft($/, "pl5", %table);
  }
  method pl7($/) {
    given ~$<op> {
      when "!" {
        return $/.make: [Not, $<pl6>.made];
      }
      when "+-" {
        return $/.make: [BNot, $<pl6>.made];
      }
      return $/.make: $<pl6>.made;
    }
  }
  method pl8($/) {
    my %table =
      "&" => And,
      "|" => Or,
      "Q" => Xor,
      "+&" => BAnd,
      "+|" => BOr,
      "+Q" => BXor;
    tumbleLeft($/, "pl7", %table);
  }
  method pl9($/) {
    return $/.make: $<pl8>[0].made if $<pl8>.elems == 1 && !~$0;
    $/.make: [ListOf, $<pl8>».made];
  }
  method pl10($/) {
    return $/.make: $<pl9>.made if !~$<op>;
    given ord ~$<op> {
      when 82 {
        my %table =
          "R+" => ReadInt,
          "R~" => ReadChars,
          "R~~" => ReadLine,
          "R." => ReadFloat;
        $/.make: [%table{~$<op>}, $<pl9>.made];
      }
      when 68 {
        my %table =
          "~" => DList,
          "+" => DInt,
          "." => DFloat;
        $/.make: [Convert, $<pl9>.made, %table{$0[0]}, %table{$0[1]}];
      }
    }
  }
  method expression($/) {
    $/.make: $<pl10>.made;
  }
}

sub MAIN(Str $file, Bool :$casual, Bool :$hardcore) {
  if ($casual && $hardcore) {
    note qq:to/STUPID/;
    $U are stupid and think you can be casual and hardcore simultaneously.
    $U have little knowledge of vocabulary.
    STUPID
    exit 1;
  } elsif ($casual) {
    note qq:to/CASUAL/;
    $U are casual, and $U can hardly think.
    $U were probably dropped on the head shortly after birth.
    CASUAL
  }
  say i2f(3);
  say f2i(Num(0.9));
  try {
    my $src = $file.IO.slurp.trim;
    say $src;
    say U.parse($src, actions => Uctions).made;
    CATCH {
      when / "Failed to open file" / {
        note qq:to/NOFILE/;
        $U think $U fed something to the dragon,
        but $U fed only thin air.
        Shame on $U.
        NOFILE
        exit 1;
      }
    }
  }
}
