#!/usr/bin/env perl6

use v6;

grammar U {
  token TOP { ^ <statements> $ }
  token statements {
    [<statement>? <sep>]* <statement>?
  }
  token number { 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 }
  token num-identifier { <[ a .. z ]> | ' ' }
  token list-identifier { L . . }
  token func-identifier { Y . . }
  token block-identifier { '"' <[ -" ]>* '"' }
  token ans { '_' }
  token ten { X }
  token identifier {
    <num-identifier> | <list-identifier> |
    <func-identifier> | <block-identifier>
  }
  regex lvalue {
    <identifier> |
    [ <list-identifier> <expression> ] |
    [ '*' | <expression> ]
  }
  token sep { \v | ':' }
  token cflow {
    [ $<keyword> = [ '?' | '?@' | '?@!' ] <cond=.expression> <sep> <body=.expression>] |
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
    [ $<op> = <[ * P T ]> <pl0> ] |
    [ <pl0> $<op> = <[ F I ]>? ]
  }
  token pl2 {
    [ <left=.pl1> $<op> = <[ O U ]> <right=.pl1> ] | <pl1>
  }
  token pl3 {
    [ <pl2> [ $<op> = [ '^' | '.^' ] <pl2> ]* ]
  }
  token pl4 {
    [ <pl3> [ $<op> = [ '/' | './' | '.*' | '+<' | '+>' | '+<^' | '+>^' ]? <pl3> ]* ]
  }
  token pl5 {
    [ <pl4> [ $<op> = [ '+' | '-' | '.+' | '.-' | '+&' | '+|' | '+Q' ] <pl4> ]* ]
  }
  token pl6 {
    [ <pl5> [ $<op> = [ '=' | '<' | '>' | '.=' | '.<' | '.>' ] <pl5> ]* ]
  }
  token pl7 {
    $<op> = '!'? <pl6>
  }
  token pl8 {
    [ <pl7> [ $<op> = [ '&' | '|' | Q ] <pl7> ]* ]
  }
  token pl9 {
    [ <pl8> [ ',' <pl8> ]* ','? ]
  }
  token pl10 {
    [ $<op> = [ 'R+' | 'R~' | 'R~~' | 'R.' | [ D <[ ~ + . ]> ** 2 ] ] <pl9> ] |
    <pl9>
  }
  token expression {
    <pl10>
  }
}

sub MAIN(Str $file, Bool :$casual, Bool :$hardcore) {
  if ($casual && $hardcore) {
    note "It is not possible to be casual and hardcore simultaneously.";
    exit 1;
  } elsif ($casual) {
    note "User is a filthy casual who can't use their brain.";
  }
  my $src = $file.IO.slurp.trim;
  say $src;
  say U.parse: $src;
}
