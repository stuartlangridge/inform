[CodeGen::CL::] Constants and Literals.

To generate final code for constants, including arrays.

@

=
int the_quartet_found = FALSE;
int box_mode = FALSE, printing_mode = FALSE;

void CodeGen::CL::prepare(code_generation *gen) {
	the_quartet_found = FALSE;
	box_mode = FALSE; printing_mode = FALSE;
}

@

=
void CodeGen::CL::responses(code_generation *gen) {
	int NR = 0;
	Inter::Packages::traverse(gen, CodeGen::CL::response_visitor, &NR);
	if (NR > 0) {
		generated_segment *saved = CodeGen::select(gen, CodeGen::Targets::constant_segment(gen));
		CodeGen::Targets::begin_constant(gen, I"NO_RESPONSES", TRUE);
		WRITE_TO(CodeGen::current(gen), "%d", NR);
		CodeGen::Targets::end_constant(gen, I"NO_RESPONSES");
		CodeGen::deselect(gen, saved);
		saved = CodeGen::select(gen, CodeGen::Targets::default_segment(gen));
		WRITE_TO(CodeGen::current(gen), "Array ResponseTexts --> ");
		Inter::Packages::traverse(gen, CodeGen::CL::response_revisitor, NULL);
		WRITE_TO(CodeGen::current(gen), "0 0;\n");
		CodeGen::deselect(gen, saved);
	}
}

@

=
void CodeGen::CL::response_visitor(code_generation *gen, inter_frame P, void *state) {
	if (P.data[ID_IFLD] == RESPONSE_IST) {
		int *NR = (int *) state;
		generated_segment *saved = CodeGen::select(gen, CodeGen::Targets::general_segment(gen, P));
		inter_symbol *resp_name = Inter::SymbolsTables::symbol_from_frame_data(P, DEFN_RESPONSE_IFLD);
		CodeGen::Targets::begin_constant(gen, CodeGen::CL::name(resp_name), TRUE);
		text_stream *OUT = CodeGen::current(gen);
		*NR = *NR + 1;
		WRITE("%d", *NR);
		CodeGen::Targets::end_constant(gen, CodeGen::CL::name(resp_name));
		CodeGen::deselect(gen, saved);
	}
}

void CodeGen::CL::response_revisitor(code_generation *gen, inter_frame P, void *state) {
	if (P.data[ID_IFLD] == RESPONSE_IST) {
		CodeGen::CL::literal(gen, NULL, Inter::Packages::scope_of(P), P.data[VAL1_RESPONSE_IFLD], P.data[VAL1_RESPONSE_IFLD+1], FALSE);
		WRITE_TO(CodeGen::current(gen), " ");
	}
}

@

There's a contrivance here to get around an awkward point of I6 syntax:
an array written in the form

	|Array X table 20;|

makes a table with 20 entries, not a table with one entry whose initial value
is 20. We instead compile this as

	|Array X --> 1 20;|

=
int CodeGen::CL::quartet_present(void) {
	#ifdef CORE_MODULE
	return TRUE;
	#endif
	#ifndef CORE_MODULE
	return the_quartet_found;
	#endif	
}

void CodeGen::CL::constant(code_generation *gen, inter_frame P) {
	text_stream *OUT = CodeGen::current(gen);
	inter_symbol *con_name = Inter::SymbolsTables::symbol_from_frame_data(P, DEFN_CONST_IFLD);

	if (Inter::Symbols::read_annotation(con_name, INLINE_ARRAY_IANN) == 1) return;
	if (Inter::Symbols::read_annotation(con_name, ACTION_IANN) == 1) return;

	if (Inter::Symbols::read_annotation(con_name, FAKE_ACTION_IANN) == 1) {
		text_stream *fa = Str::duplicate(con_name->symbol_name);
		Str::delete_first_character(fa);
		Str::delete_first_character(fa);
		WRITE("Fake_Action %S;\n", fa);
		return;
	}

	int ifndef_me = FALSE;
	if (Inter::Symbols::read_annotation(con_name, VENEER_IANN) == 1) return;
	if ((Str::eq(con_name->symbol_name, I"WORDSIZE")) ||
		(Str::eq(con_name->symbol_name, I"TARGET_ZCODE")) ||
		(Str::eq(con_name->symbol_name, I"INDIV_PROP_START")) ||
		(Str::eq(con_name->symbol_name, I"TARGET_GLULX")) ||
		(Str::eq(con_name->symbol_name, I"DICT_WORD_SIZE")) ||
		(Str::eq(con_name->symbol_name, I"DEBUG")))
		ifndef_me = TRUE;

	if (Str::eq(con_name->symbol_name, I"thedark")) {
		the_quartet_found = TRUE;
//		WRITE("Object thedark \"(darkness object)\";\n");
		return;
	}
	if (Str::eq(con_name->symbol_name, I"InformLibrary")) {
		the_quartet_found = TRUE;
//		WRITE("Object InformLibrary \"(Inform Library)\" has proper;\n");
		return;
	}
	if (Str::eq(con_name->symbol_name, I"InformParser")) {
		the_quartet_found = TRUE;
//		WRITE("Object InformParser \"(Inform Parser)\" has proper;\n");
		return;
	}
	if (Str::eq(con_name->symbol_name, I"Compass")) {
		the_quartet_found = TRUE;
//		WRITE("Object Compass \"compass\" has concealed;\n");
		return;
	}
	
	if (Str::eq(con_name->symbol_name, I"Release")) {
		inter_t val1 = P.data[DATA_CONST_IFLD];
		inter_t val2 = P.data[DATA_CONST_IFLD + 1];
		WRITE("Release ");
		CodeGen::CL::literal(gen, NULL, Inter::Packages::scope_of(P), val1, val2, FALSE);
		WRITE(";\n");
		return;
	}

	if (Str::eq(con_name->symbol_name, I"Story")) {
		inter_t val1 = P.data[DATA_CONST_IFLD];
		inter_t val2 = P.data[DATA_CONST_IFLD + 1];
		WRITE("Global Story = ");
		CodeGen::CL::literal(gen, NULL, Inter::Packages::scope_of(P), val1, val2, FALSE);
		WRITE(";\n");
		return;
	}

	if (Str::eq(con_name->symbol_name, I"Serial")) {
		inter_t val1 = P.data[DATA_CONST_IFLD];
		inter_t val2 = P.data[DATA_CONST_IFLD + 1];
		WRITE("Serial ");
		CodeGen::CL::literal(gen, NULL, Inter::Packages::scope_of(P), val1, val2, FALSE);
		WRITE(";\n");
		return;
	}

	if (Str::eq(con_name->symbol_name, I"UUID_ARRAY")) {
		inter_t ID = P.data[DATA_CONST_IFLD];
		text_stream *S = Inter::get_text(P.repo_segment->owning_repo, ID);
		WRITE("Array UUID_ARRAY string \"UUID://");
		for (int i=0, L=Str::len(S); i<L; i++) WRITE("%c", Characters::toupper(Str::get_at(S, i)));
		WRITE("//\";\n");
		return;
	}

	if (Inter::Constant::is_routine(con_name)) {
		inter_symbol *code_block = Inter::Constant::code_block(con_name);
		if (CodeGen::Eliminate::gone(code_block) == FALSE) {
			WRITE("[ %S", CodeGen::CL::name(con_name));
			void_level = Inter::Defn::get_level(P) + 2;
			inter_frame D = Inter::Symbols::defining_frame(code_block);
			CodeGen::FC::frame(gen, D);
		}
		return;
	}
	switch (P.data[FORMAT_CONST_IFLD]) {
		case CONSTANT_INDIRECT_TEXT: {
			inter_t ID = P.data[DATA_CONST_IFLD];
			text_stream *S = Inter::get_text(P.repo_segment->owning_repo, ID);
			CodeGen::Targets::begin_constant(gen, CodeGen::CL::name(con_name), TRUE);
			WRITE("\"%S\"", S);
			CodeGen::Targets::end_constant(gen, CodeGen::CL::name(con_name));
			break;
		}
		case CONSTANT_INDIRECT_LIST: {
			char *format = "-->";
			int do_not_bracket = FALSE, unsub = FALSE;
			int X = (P.extent - DATA_CONST_IFLD)/2;
			if (X == 1) do_not_bracket = TRUE;
			if (Inter::Symbols::read_annotation(con_name, BYTEARRAY_IANN) == 1) format = "->";
			if (Inter::Symbols::read_annotation(con_name, TABLEARRAY_IANN) == 1) {
				format = "table";
				if (P.extent - DATA_CONST_IFLD == 2) format = "--> 1";
			}
			if (Inter::Symbols::read_annotation(con_name, BUFFERARRAY_IANN) == 1) format = "buffer";
			if (Inter::Symbols::read_annotation(con_name, STRINGARRAY_IANN) == 1) { format = "string"; do_not_bracket = TRUE; }
			if (Inter::Symbols::read_annotation(con_name, VERBARRAY_IANN) == 1) {
				WRITE("Verb "); do_not_bracket = TRUE; unsub = TRUE;
				if (Inter::Symbols::read_annotation(con_name, METAVERB_IANN) == 1) WRITE("meta ");
			} else {
				WRITE("Array %S %s", CodeGen::CL::name(con_name), format);
			}
			for (int i=DATA_CONST_IFLD; i<P.extent; i=i+2) {
				WRITE(" ");
				if ((do_not_bracket == FALSE) && (P.data[i] != DIVIDER_IVAL)) WRITE("(");
				CodeGen::CL::literal(gen, con_name, Inter::Packages::scope_of(P), P.data[i], P.data[i+1], unsub);
				if ((do_not_bracket == FALSE) && (P.data[i] != DIVIDER_IVAL)) WRITE(")");
			}
			WRITE(";\n");
			break;
		}
		case CONSTANT_SUM_LIST:
		case CONSTANT_PRODUCT_LIST:
		case CONSTANT_DIFFERENCE_LIST:
		case CONSTANT_QUOTIENT_LIST:
			CodeGen::Targets::begin_constant(gen, CodeGen::CL::name(con_name), TRUE);
			for (int i=DATA_CONST_IFLD; i<P.extent; i=i+2) {
				if (i>DATA_CONST_IFLD) {
					if (P.data[FORMAT_CONST_IFLD] == CONSTANT_SUM_LIST) WRITE(" + ");
					if (P.data[FORMAT_CONST_IFLD] == CONSTANT_PRODUCT_LIST) WRITE(" * ");
					if (P.data[FORMAT_CONST_IFLD] == CONSTANT_DIFFERENCE_LIST) WRITE(" - ");
					if (P.data[FORMAT_CONST_IFLD] == CONSTANT_QUOTIENT_LIST) WRITE(" / ");
				}
				int bracket = TRUE;
				if ((P.data[i] == LITERAL_IVAL) || (Inter::Symbols::is_stored_in_data(P.data[i], P.data[i+1]))) bracket = FALSE;
				if (bracket) WRITE("(");
				CodeGen::CL::literal(gen, con_name, Inter::Packages::scope_of(P), P.data[i], P.data[i+1], FALSE);
				if (bracket) WRITE(")");
			}
			CodeGen::Targets::end_constant(gen, CodeGen::CL::name(con_name));
			break;
		case CONSTANT_DIRECT: {
			inter_t val1 = P.data[DATA_CONST_IFLD];
			inter_t val2 = P.data[DATA_CONST_IFLD + 1];
			if (ifndef_me) WRITE("#ifndef %S;\n", CodeGen::CL::name(con_name));
			CodeGen::Targets::begin_constant(gen, CodeGen::CL::name(con_name), TRUE);
			CodeGen::CL::literal(gen, con_name, Inter::Packages::scope_of(P), val1, val2, FALSE);
			CodeGen::Targets::end_constant(gen, CodeGen::CL::name(con_name));
			if (ifndef_me) WRITE(" #endif;\n");
			break;
		}
		default: internal_error("ungenerated constant format");
	}
}

typedef struct text_literal_holder {
	struct text_stream *definition_code;
	struct text_stream *literal_content;
	MEMORY_MANAGEMENT
} text_literal_holder;

text_stream *CodeGen::CL::literal_text_at(code_generation *gen, text_stream *S) {
	text_literal_holder *tlh = CREATE(text_literal_holder);
	tlh->definition_code = Str::new();
	tlh->literal_content = S;
	return tlh->definition_code;
}

int CodeGen::CL::compare_tlh(const void *elem1, const void *elem2) {
	const text_literal_holder **e1 = (const text_literal_holder **) elem1;
	const text_literal_holder **e2 = (const text_literal_holder **) elem2;
	if ((*e1 == NULL) || (*e2 == NULL))
		internal_error("Disaster while sorting text literals");
	text_stream *s1 = (*e1)->literal_content;
	text_stream *s2 = (*e2)->literal_content;
	return Str::cmp(s1, s2);
}

void CodeGen::CL::sort_literals(code_generation *gen) {
	int no_tlh = NUMBER_CREATED(text_literal_holder);
	text_literal_holder **sorted = (text_literal_holder **)
			(Memory::I7_calloc(no_tlh, sizeof(text_literal_holder *), CODE_GENERATION_MREASON));
	int i = 0;
	text_literal_holder *tlh;
	LOOP_OVER(tlh, text_literal_holder) sorted[i++] = tlh;

	qsort(sorted, (size_t) no_tlh, sizeof(text_literal_holder *), CodeGen::CL::compare_tlh);
	for (int i=0; i<no_tlh; i++) {
		text_literal_holder *tlh = sorted[i];
		generated_segment *saved = CodeGen::select(gen, CodeGen::Targets::tl_segment(gen));
		text_stream *TO = CodeGen::current(gen);
		WRITE_TO(TO, "%S", tlh->definition_code);
		CodeGen::deselect(gen, saved);
	}
}

void CodeGen::CL::enter_box_mode(void) {
	box_mode = TRUE;
}

void CodeGen::CL::exit_box_mode(void) {
	box_mode = FALSE;
}

void CodeGen::CL::enter_print_mode(void) {
	printing_mode = TRUE;
}

void CodeGen::CL::exit_print_mode(void) {
	printing_mode = FALSE;
}

void CodeGen::CL::literal(code_generation *gen, inter_symbol *con_name, inter_symbols_table *T, inter_t val1, inter_t val2, int unsub) {
	inter_repository *I = gen->from;
	text_stream *OUT = CodeGen::current(gen);
	if (val1 == LITERAL_IVAL) {
		int hex = FALSE;
		if (con_name)
			for (int i=0; i<con_name->no_symbol_annotations; i++)
				if (con_name->symbol_annotations[i].annot->annotation_ID == HEX_IANN)
					hex = TRUE;
		if (hex) WRITE("$%x", val2);
		else WRITE("%d", val2);
	} else if (Inter::Symbols::is_stored_in_data(val1, val2)) {
		inter_symbol *aliased = Inter::SymbolsTables::symbol_from_data_pair_and_table(val1, val2, T);
		if (aliased == NULL) internal_error("bad aliased symbol");
		if (aliased == verb_directive_divider_symbol) WRITE("\n\t*");
		else if (aliased == verb_directive_reverse_symbol) WRITE("reverse");
		else if (aliased == verb_directive_slash_symbol) WRITE("/");
		else if (aliased == verb_directive_result_symbol) WRITE("->");
		else if (aliased == verb_directive_special_symbol) WRITE("special");
		else if (aliased == verb_directive_number_symbol) WRITE("number");
		else if (aliased == verb_directive_noun_symbol) WRITE("noun");
		else if (aliased == verb_directive_multi_symbol) WRITE("multi");
		else if (aliased == verb_directive_multiinside_symbol) WRITE("multiinside");
		else if (aliased == verb_directive_multiheld_symbol) WRITE("multiheld");
		else if (aliased == verb_directive_held_symbol) WRITE("held");
		else if (aliased == verb_directive_creature_symbol) WRITE("creature");
		else if (aliased == verb_directive_topic_symbol) WRITE("topic");
		else if (aliased == verb_directive_multiexcept_symbol) WRITE("multiexcept");
		else {
			if ((unsub) && (Inter::Symbols::read_annotation(aliased, SCOPE_FILTER_IANN) == 1))
				WRITE("scope=");
			if ((unsub) && (Inter::Symbols::read_annotation(aliased, NOUN_FILTER_IANN) == 1))
				WRITE("noun=");
			text_stream *S = CodeGen::CL::name(aliased);
			if ((unsub) && (Str::begins_with_wide_string(S, L"##"))) {
				LOOP_THROUGH_TEXT(pos, S)
					if (pos.index >= 2)
						PUT(Str::get(pos));
			} else {
				WRITE("%S", S);
			}
		}
	} else if (val1 == DIVIDER_IVAL) {
		text_stream *divider_text = Inter::get_text(I, val2);
		WRITE(" ! %S\n\t", divider_text);
	} else if (val1 == REAL_IVAL) {
		text_stream *glob_text = Inter::get_text(I, val2);
		WRITE("$%S", glob_text);
	} else if (val1 == DWORD_IVAL) {
		text_stream *glob_text = Inter::get_text(I, val2);
		CodeGen::Targets::compile_dictionary_word(gen, glob_text, FALSE);
	} else if (val1 == PDWORD_IVAL) {
		text_stream *glob_text = Inter::get_text(I, val2);
		CodeGen::Targets::compile_dictionary_word(gen, glob_text, TRUE);
	} else if (val1 == LITERAL_TEXT_IVAL) {
		text_stream *glob_text = Inter::get_text(I, val2);
		CodeGen::Targets::compile_literal_text(gen, glob_text, printing_mode, box_mode);
	} else if (val1 == GLOB_IVAL) {
		text_stream *glob_text = Inter::get_text(I, val2);
		WRITE("%S", glob_text);
	} else internal_error("unimplemented direct constant");
}

text_stream *CodeGen::CL::name(inter_symbol *symb) {
	if (symb == NULL) return NULL;
	if (Inter::Symbols::get_translate(symb)) return Inter::Symbols::get_translate(symb);
	return symb->symbol_name;
}