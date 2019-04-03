Inform Organisation.

The standard hierarchy of inter code generated by Inform.

@h Status.
The Inter specification allows great flexibility in how packages are used
to structure a program, and requires very little.

The Inform compiler, however, uses this flexibility in a systematic way,
as follows.

@h Global area and main.
Inform opens with a version number, then declares package types (as needed
below), issues pragmas for I6 compiler memory settings, then declares
primitives for the standard Inform set: it always declares the same set
of primitives on every run.

As required, the rest of the program is in the |main| package, and much of
it in a plain module called |/main/resources|.

@h Compilation modules.
Inform divides up its material into compilation modules, as follows. Each
one becomes an inter package of type |_module|, as a subpackage
of |/main/resources|.

(a) The "generic module" contains built-in definitions of kinds, and the like.
No source text directly leads to this, and indeed, it can entirely be defined
without having seen any source text: it will be the same on every run. The
package is |/main/resources/generic|.

(b) Material from the Inform 6 template is assimilated into inter code in
the "template module", which is |/main/resources/template|.

(c) Each extension is a compilation module, including of course the Standard
Rules, which is |/main/resources/standard_rules|. Subsequent extensions have
longer names, such as |/main/resources/locksmith_by_emily_short|.

(d) Material in the main source text is a single compilation module, and
goes into |/main/resources/source_text|.

(e) The "synoptic module" contains material which was synthesised from all
of the source material in the other modules, and which can't meaningfully
be localised. For example, a function at run-time which returns the default
value for a kind given its weak kind ID has to be synoptic, because its
definition will include references to every kind defined in the program.
Such a function doesn't belong to any one block of source text. The
package is |/main/resources/synoptic|.

@ Except for the template module, which is necessarily more free-form,
each module package then contains some or all of a standard set of
subpackages (and nothing else). Suppose the module name is |M|. The
range of possible subpackages is:

	|/main/resources/M/actions|
	|/main/resources/M/activities|
	|/main/resources/M/adjectives|
	|/main/resources/M/chronology|
	|/main/resources/M/conjugations|
	|/main/resources/M/equations|
	|/main/resources/M/extensions|
	|/main/resources/M/grammar|
	|/main/resources/M/instances|
	|/main/resources/M/kinds|
	|/main/resources/M/listing|
	|/main/resources/M/phrases|
	|/main/resources/M/properties|
	|/main/resources/M/relations|
	|/main/resources/M/rulebooks|
	|/main/resources/M/rules|
	|/main/resources/M/tables|
	|/main/resources/M/variables|

@h Function packages.
All functions compiled by Inform 7 are expressed in inter code by packages
of type |_function|. The only externally visible symbol is |call|, which is
what is invoked. For example:

	|symbol X == /main/resources/kinds/kind_6/gpr_fn/call|
	|...|
	|        inv X|

invokes the function defined by the package:

	|inv /main/resources/kinds/kind_6/gpr_fn|

(Inform conventionally uses names ending in |_fn| for function packages.)

It is possible for function packages to avoid defining any actual code, by
defining |call| as an alias for a routine which we'll simply have to assume
will be present at eventual compile time. For example:

	|package print_fn _function|
	|    symbol public misc call -> REAL_NUMBER_TY_Say|

More often, however, and always for functions derived from Inform 7 source
text, the package contains a code subpackage, and then defines |call| to
be that code package:

	|package gpr_fn _function|
	|    package code_block_1 _code|
	|        ...|
	|    constant call K_phrase_nothing____nothing = code_block_1|

In fact, though, the package can be much more elaborate. If the code needs
to manipulate or refer to data not expressible in single words, such as
lists or texts, then it will probably need to create and subsequently destroy
a stack frame. The mechanism will then be:

	|package gpr_fn _function|
	|    package code_block_1 _code|
	|        ...|
	|    constant kernel K_phrase_nothing____nothing = code_block_1|
	|    package code_block_2 _code|
	|        ...|
	|    constant call K_phrase_nothing____nothing = code_block_2|

The "shell" routine of code, the one receiving the |call|, creates a stack
fram and then calls the "kernel" routine, which does the actual work; when
that returns to the "shell", the stack frame is disposed of again.

Function packages will also contain definitions of any static data they
need: for example, if an Inform 7 phrase contains a reference to the 
constant |{ 1 , 2 , 3 }| then a function package for it will define a
constant with a name such as |block_constant_1|. In short, as far as
possible, function packages are self-contained.

	




