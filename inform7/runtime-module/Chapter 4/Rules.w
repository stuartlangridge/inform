[RTRules::] Rules.

To compile run-time support for rules.

@

= (early code)
rule *rule_being_compiled = NULL; /* rule whose phrase's definition is being compiled */
rule *adopted_rule_for_compilation = NULL; /* when a new response is being compiled */
int adopted_marker_for_compilation = -1; /* when a new response is being compiled */

@ In Inter code, a rule is compiled to the name of the routine implementing it.

=
typedef struct rule_compilation_data {
	struct package_request *rule_package;
	struct inter_name *shell_routine_iname;
	struct inter_name *rule_extern_iname; /* if externally defined, this is the I6 routine */
	struct inter_name *xiname;
	struct inter_name *rule_extern_response_handler_iname; /* and this produces any response texts it has */
	int defn_compiled; /* has the definition of this rule, if needed, been compiled yet? */
} rule_compilation_data;

rule_compilation_data RTRules::new_compilation_data(rule *R) {
	rule_compilation_data rcd;
	rcd.rule_extern_iname = NULL;
	rcd.xiname = NULL;
	rcd.rule_extern_response_handler_iname = NULL;
	rcd.shell_routine_iname = NULL;
	rcd.rule_package = Hierarchy::local_package(RULES_HAP);
	rcd.defn_compiled = FALSE;
	if (Wordings::nonempty(R->name))
		Hierarchy::markup_wording(rcd.rule_package, RULE_NAME_HMD, R->name);
	return rcd;
}

ph_stack_frame *RTRules::stack_frame(rule *R) {
	if ((R == NULL) || (R->defn_as_phrase == NULL)) return NULL;
	return &(R->defn_as_phrase->stack_frame);
}

package_request *RTRules::package(rule *R) {
	return R->compilation_data.rule_package;
}

inter_name *RTRules::shell_iname(rule *R) {
	if (R->compilation_data.shell_routine_iname == NULL)
		R->compilation_data.shell_routine_iname = Hierarchy::make_iname_in(SHELL_FN_HL, R->compilation_data.rule_package);
	return R->compilation_data.shell_routine_iname;
}

inter_name *RTRules::iname(rule *R) {
	if (R->defn_as_phrase) return Phrases::iname(R->defn_as_phrase);
	else if (R->compilation_data.rule_extern_iname) {
		if (LinkedLists::len(R->applicability_constraints) > 0) {
			return RTRules::shell_iname(R);
		} else {
			return R->compilation_data.rule_extern_iname;
		}
	} else internal_error("tried to symbolise nameless rule");
	return NULL;
}

void RTRules::define_by_Inter_function(rule *R) {
	R->compilation_data.rule_extern_iname = Hierarchy::make_iname_in(EXTERIOR_RULE_HL, R->compilation_data.rule_package);

	inter_name *xiname = Produce::find_by_name(Emit::tree(), R->defn_as_Inter_function);
	Emit::named_generic_constant_xiname(R->compilation_data.rule_package, R->compilation_data.rule_extern_iname, xiname);

	R->compilation_data.xiname = xiname;
}

inter_name *RTRules::get_handler_definition(rule *R) {
	if (R->compilation_data.rule_extern_response_handler_iname == NULL) {
		R->compilation_data.rule_extern_response_handler_iname =
			Hierarchy::derive_iname_in(RESPONDER_FN_HL, R->compilation_data.xiname, R->compilation_data.rule_package);
		Hierarchy::make_available(Emit::tree(), R->compilation_data.rule_extern_response_handler_iname);
	}
	return R->compilation_data.rule_extern_response_handler_iname;
}

@h Compilation.
Only those rules defined as I7 phrases need us to compile anything -- and then
what we compile, of course, is the phrase in question.

=
void RTRules::compile_definition(rule *R, int *i, int max_i) {
	if (R->compilation_data.defn_compiled == FALSE) {
		R->compilation_data.defn_compiled = TRUE;
		rule_being_compiled = R;
		if (R->defn_as_phrase)
			Phrases::compile(R->defn_as_phrase, i, max_i,
				R->variables_visible_in_definition, NULL, R);
		if ((R->compilation_data.rule_extern_iname) &&
			(LinkedLists::len(R->applicability_constraints) > 0))
			@<Compile a shell routine to apply conditions to an I6 rule@>;
		rule_being_compiled = NULL;
	}
}

@ This is the trickiest case: where the user has asked for something like

>> The carrying requirements rule does nothing when eating the lollipop.

and the carrying requirements rule is defined by an I6 routine, which we
are unable to modify. What we do is to create a shell routine to call it,
and put the conditions into this outer shell; we then use the outer shell
as the definition of the rule in future.

@<Compile a shell routine to apply conditions to an I6 rule@> =
	inter_name *shell_iname = RTRules::shell_iname(R);
	packaging_state save = Routines::begin(shell_iname);
	if (RTRules::compile_constraint(R) == FALSE) {
		Produce::inv_primitive(Emit::tree(), RETURN_BIP);
		Produce::down(Emit::tree());
		Produce::inv_call_iname(Emit::tree(), R->compilation_data.rule_extern_iname);
		Produce::up(Emit::tree());
	}
	Routines::end(save);

@ The following generates code to terminate a rule early if its applicability
conditions have not been met.

=
int RTRules::compile_constraint(rule *R) {
	if (R) {
		applicability_constraint *acl;
		LOOP_OVER_LINKED_LIST(acl, applicability_constraint, R->applicability_constraints) {
			current_sentence = acl->where_imposed;
			if (Wordings::nonempty(acl->text_of_condition)) {
				Produce::inv_primitive(Emit::tree(), IF_BIP);
				Produce::down(Emit::tree());
				if (acl->sense_of_applicability) {
					Produce::inv_primitive(Emit::tree(), NOT_BIP);
					Produce::down(Emit::tree());
				}
				@<Compile the constraint condition@>;
				if (acl->sense_of_applicability) {
					Produce::up(Emit::tree());
				}
				Produce::code(Emit::tree());
				Produce::down(Emit::tree());
			}
			@<Compile the rule termination code used if the constraint was violated@>;
			if (Wordings::nonempty(acl->text_of_condition)) {
				Produce::up(Emit::tree());
				Produce::up(Emit::tree());
			} else {
				return TRUE;
			}
		}
	}
	return FALSE;
}

@<Compile the constraint condition@> =
	if (Wordings::nonempty(acl->text_of_condition) == FALSE) {
		Produce::val(Emit::tree(), K_truth_state, LITERAL_IVAL, 1);
	} else {
		if (<s-condition>(acl->text_of_condition)) {
			parse_node *spec = <<rp>>;
			Dash::check_condition(spec);
			Specifications::Compiler::emit_as_val(K_truth_state, spec);
		} else {
			Problems::quote_source(1, current_sentence);
			Problems::quote_wording(2, acl->text_of_condition);
			StandardProblems::handmade_problem(Task::syntax_tree(), _p_(PM_BadRuleConstraint));
			Problems::issue_problem_segment(
				"In %1, you placed a constraint '%2' on a rule, but this isn't "
				"a condition I can understand.");
			Problems::issue_problem_end();
			Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 1);
		}
	}

@ Note that in the does nothing case, the rule ends without result, rather than
failing; so it doesn't terminate the following of its rulebook.

@<Compile the rule termination code used if the constraint was violated@> =
	Produce::inv_primitive(Emit::tree(), RETURN_BIP);
	Produce::down(Emit::tree());
	if (acl->substituted_rule) {
		inter_name *subbed = RTRules::iname(acl->substituted_rule);
		if (Inter::Constant::is_routine(InterNames::to_symbol(subbed)) == FALSE) {
			Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 0);
		} else {
			Produce::inv_call_iname(Emit::tree(), subbed);
		}
	} else {
		Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 0);
	}
	Produce::up(Emit::tree());

@h Printing rule names at run time.

=
void RTRules::RulePrintingRule_routine(void) {
	inter_name *iname = Hierarchy::find(RULEPRINTINGRULE_HL);
	packaging_state save = Routines::begin(iname);
	inter_symbol *R_s = LocalVariables::add_named_call_as_symbol(I"R");
	Produce::inv_primitive(Emit::tree(), IFELSE_BIP);
	Produce::down(Emit::tree());
		Produce::inv_primitive(Emit::tree(), AND_BIP);
		Produce::down(Emit::tree());
			Produce::inv_primitive(Emit::tree(), GE_BIP);
			Produce::down(Emit::tree());
				Produce::val_symbol(Emit::tree(), K_value, R_s);
				Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 0);
			Produce::up(Emit::tree());
			Produce::inv_primitive(Emit::tree(), LT_BIP);
			Produce::down(Emit::tree());
				Produce::val_symbol(Emit::tree(), K_value, R_s);
				Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(NUMBER_RULEBOOKS_CREATED_HL));
			Produce::up(Emit::tree());
		Produce::up(Emit::tree());
		Produce::code(Emit::tree());
		Produce::down(Emit::tree());
			@<Print a rulebook name@>;
		Produce::up(Emit::tree());
		Produce::code(Emit::tree());
		Produce::down(Emit::tree());
			@<Print a rule name@>;
		Produce::up(Emit::tree());
	Produce::up(Emit::tree());
	Routines::end(save);
	Hierarchy::make_available(Emit::tree(), iname);
}

@<Print a rulebook name@> =
	if (global_compilation_settings.memory_economy_in_force) {
		Produce::inv_primitive(Emit::tree(), PRINT_BIP);
		Produce::down(Emit::tree());
			Produce::val_text(Emit::tree(), I"(rulebook ");
		Produce::up(Emit::tree());
		Produce::inv_primitive(Emit::tree(), PRINTNUMBER_BIP);
		Produce::down(Emit::tree());
			Produce::val_symbol(Emit::tree(), K_value, R_s);
		Produce::up(Emit::tree());
		Produce::inv_primitive(Emit::tree(), PRINT_BIP);
		Produce::down(Emit::tree());
			Produce::val_text(Emit::tree(), I")");
		Produce::up(Emit::tree());
	} else {
		Produce::inv_primitive(Emit::tree(), PRINTSTRING_BIP);
		Produce::down(Emit::tree());
			Produce::inv_primitive(Emit::tree(), LOOKUP_BIP);
			Produce::down(Emit::tree());
				Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(RULEBOOKNAMES_HL));
				Produce::val_symbol(Emit::tree(), K_value, R_s);
			Produce::up(Emit::tree());
		Produce::up(Emit::tree());
	}

@<Print a rule name@> =
	if (global_compilation_settings.memory_economy_in_force) {
		Produce::inv_primitive(Emit::tree(), PRINT_BIP);
		Produce::down(Emit::tree());
			Produce::val_text(Emit::tree(), I"(rule at address ");
		Produce::up(Emit::tree());
		Produce::inv_primitive(Emit::tree(), PRINTNUMBER_BIP);
		Produce::down(Emit::tree());
			Produce::val_symbol(Emit::tree(), K_value, R_s);
		Produce::up(Emit::tree());
		Produce::inv_primitive(Emit::tree(), PRINT_BIP);
		Produce::down(Emit::tree());
			Produce::val_text(Emit::tree(), I")");
		Produce::up(Emit::tree());
	} else {
		rule *R;
		LOOP_OVER(R, rule) {
			if ((Wordings::nonempty(R->name) == FALSE) &&
				((R->defn_as_phrase == NULL) ||
					(R->defn_as_phrase->declaration_node == NULL) ||
					(R->defn_as_phrase->declaration_node->down == NULL)))
					continue;
			Produce::inv_primitive(Emit::tree(), IF_BIP);
			Produce::down(Emit::tree());
				Produce::inv_primitive(Emit::tree(), EQ_BIP);
				Produce::down(Emit::tree());
					Produce::val_symbol(Emit::tree(), K_value, R_s);
					Produce::val_iname(Emit::tree(), K_value, RTRules::iname(R));
				Produce::up(Emit::tree());
				Produce::code(Emit::tree());
				Produce::down(Emit::tree());
					TEMPORARY_TEXT(OUT)
					@<Print a textual name for this rule@>;
					Produce::inv_primitive(Emit::tree(), PRINT_BIP);
					Produce::down(Emit::tree());
						Produce::val_text(Emit::tree(), OUT);
					Produce::up(Emit::tree());
					Produce::rtrue(Emit::tree());
					DISCARD_TEXT(OUT)
				Produce::up(Emit::tree());
			Produce::up(Emit::tree());
		}
		Produce::inv_primitive(Emit::tree(), PRINT_BIP);
		Produce::down(Emit::tree());
			Produce::val_text(Emit::tree(), I"(nameless rule at address ");
		Produce::up(Emit::tree());
		Produce::inv_primitive(Emit::tree(), PRINTNUMBER_BIP);
		Produce::down(Emit::tree());
			Produce::val_symbol(Emit::tree(), K_value, R_s);
		Produce::up(Emit::tree());
		Produce::inv_primitive(Emit::tree(), PRINT_BIP);
		Produce::down(Emit::tree());
			Produce::val_text(Emit::tree(), I")");
		Produce::up(Emit::tree());
	}

@<Print a textual name for this rule@> =
	if (Wordings::nonempty(R->name)) {
		CompiledText::from_text(OUT, R->name);
	} else if (R->defn_as_phrase->declaration_node) {
		CompiledText::from_text(OUT,
			Articles::remove_the(
				Node::get_text(R->defn_as_phrase->declaration_node)));
	} else WRITE("%n", RTRules::iname(R));

@ =
void RTRules::compile_comment(rule *R, int index, int from) {
	TEMPORARY_TEXT(C)
	WRITE_TO(C, "Rule %d/%d", index, from);
	if (R->defn_as_phrase == NULL) {
		WRITE_TO(C, ": %n", R->compilation_data.rule_extern_iname);
	}
	Produce::comment(Emit::tree(), C);
	DISCARD_TEXT(C)
	if (R->defn_as_phrase) {
		Phrases::Usage::write_I6_comment_describing(&(R->defn_as_phrase->usage_data));
	}
}

@h Compilation of I6-format rulebook.
The following can generate both old-style array rulebooks and routine rulebooks,
which were introduced in December 2010.

=
void RTRules::start_list_compilation(void) {
	inter_name *iname = Hierarchy::find(EMPTY_RULEBOOK_INAME_HL);
	packaging_state save = Routines::begin(iname);
	LocalVariables::add_named_call(I"forbid_breaks");
	Produce::rfalse(Emit::tree());
	Routines::end(save);
	Hierarchy::make_available(Emit::tree(), iname);
}

@

@d ARRAY_RBF 1 /* format as an array simply listing the rules */
@d GROUPED_ARRAY_RBF 2 /* format as a grouped array, for quicker action testing */
@d ROUTINE_RBF 3 /* format as a routine which runs the rulebook */
@d RULE_OPTIMISATION_THRESHOLD 20 /* group arrays when larger than this number of rules */

=
inter_name *RTRules::list_compile(booking_list *L,
	inter_name *identifier, int action_based, int parameter_based) {
	if (L == NULL) return NULL;
	inter_name *rb_symb = NULL;

	int countup = BookingLists::length(L);
	if (countup == 0) {
		rb_symb = Emit::named_iname_constant(identifier, K_value,
			Hierarchy::find(EMPTY_RULEBOOK_INAME_HL));
	} else {
		int format = ROUTINE_RBF;

		@<Compile the rulebook in the given format@>;
	}
	return rb_symb;
}

@ Grouping is the practice of gathering together rules which all rely on
the same action going on; it's then efficient to test the action once rather
than once for each rule.

@<Compile the rulebook in the given format@> =
	int grouping = FALSE, group_cap = 0;
	switch (format) {
		case GROUPED_ARRAY_RBF: grouping = TRUE; group_cap = 31; break;
		case ROUTINE_RBF: grouping = TRUE; group_cap = 2000000000; break;
	}
	if (action_based == FALSE) grouping = FALSE;

	inter_symbol *forbid_breaks_s = NULL, *rv_s = NULL, *original_deadflag_s = NULL, *p_s = NULL;
	packaging_state save_array = Emit::unused_packaging_state();

	@<Open the rulebook compilation@>;
	int group_size = 0, group_started = FALSE, entry_count = 0, action_group_open = FALSE;
	LOOP_OVER_BOOKINGS(br, L) {
		parse_node *spec = Rvalues::from_rule(RuleBookings::get_rule(br));
		if (grouping) {
			if (group_size == 0) {
				if (group_started) @<End an action group in the rulebook@>;
				#ifdef IF_MODULE
				action_name *an = RTRules::br_required_action(br);
				booking *brg = br;
				while ((brg) && (an == RTRules::br_required_action(brg))) {
					group_size++;
					brg = brg->next_booking;
				}
				#endif
				#ifndef IF_MODULE
				booking *brg = br;
				while (brg) {
					group_size++;
					brg = brg->next_booking;
				}
				#endif
				if (group_size > group_cap) group_size = group_cap;
				group_started = TRUE;
				@<Begin an action group in the rulebook@>;
			}
			group_size--;
		}
		@<Compile an entry in the rulebook@>;
		entry_count++;
	}
	if (group_started) @<End an action group in the rulebook@>;
	@<Close the rulebook compilation@>;

@<Open the rulebook compilation@> =
	rb_symb = identifier;
	switch (format) {
		case ARRAY_RBF: save_array = Emit::named_array_begin(identifier, K_value); break;
		case GROUPED_ARRAY_RBF: save_array = Emit::named_array_begin(identifier, K_value); Emit::array_numeric_entry((inter_ti) -2); break;
		case ROUTINE_RBF: {
			save_array = Routines::begin(identifier);
			forbid_breaks_s = LocalVariables::add_named_call_as_symbol(I"forbid_breaks");
			rv_s = LocalVariables::add_internal_local_c_as_symbol(I"rv", "return value");
			if (countup > 1)
				original_deadflag_s = LocalVariables::add_internal_local_c_as_symbol(I"original_deadflag", "saved state");
			if (parameter_based)
				p_s = LocalVariables::add_internal_local_c_as_symbol(I"p", "rulebook parameter");

			if (countup > 1) {
				Produce::inv_primitive(Emit::tree(), STORE_BIP);
				Produce::down(Emit::tree());
					Produce::ref_symbol(Emit::tree(), K_value, original_deadflag_s);
					Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(DEADFLAG_HL));
				Produce::up(Emit::tree());
			}
			if (parameter_based) {
				Produce::inv_primitive(Emit::tree(), STORE_BIP);
				Produce::down(Emit::tree());
					Produce::ref_symbol(Emit::tree(), K_value, p_s);
					Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(PARAMETER_VALUE_HL));
				Produce::up(Emit::tree());
			}
			break;
		}
	}

@<Begin an action group in the rulebook@> =
	switch (format) {
		case GROUPED_ARRAY_RBF:
			#ifdef IF_MODULE
			if (an) Emit::array_action_entry(an); else
			#endif
				Emit::array_numeric_entry((inter_ti) -2);
			if (group_size > 1) Emit::array_numeric_entry((inter_ti) group_size);
			action_group_open = TRUE;
			break;
		case ROUTINE_RBF:
			#ifdef IF_MODULE
			if (an) {
				Produce::inv_primitive(Emit::tree(), IFELSE_BIP);
				Produce::down(Emit::tree());
					Produce::inv_primitive(Emit::tree(), EQ_BIP);
					Produce::down(Emit::tree());
						Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(ACTION_HL));
						Produce::val_iname(Emit::tree(), K_value, RTActions::double_sharp(an));
					Produce::up(Emit::tree());
					Produce::code(Emit::tree());
					Produce::down(Emit::tree());

				action_group_open = TRUE;
			}
			#endif
			break;
	}

@<Compile an entry in the rulebook@> =
	switch (format) {
		case ARRAY_RBF:
		case GROUPED_ARRAY_RBF:
			Specifications::Compiler::emit(spec);
			break;
		case ROUTINE_RBF:
			if (entry_count > 0) {
				Produce::inv_primitive(Emit::tree(), IF_BIP);
				Produce::down(Emit::tree());
					Produce::inv_primitive(Emit::tree(), NE_BIP);
					Produce::down(Emit::tree());
						Produce::val_symbol(Emit::tree(), K_value, original_deadflag_s);
						Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(DEADFLAG_HL));
					Produce::up(Emit::tree());
					Produce::code(Emit::tree());
					Produce::down(Emit::tree());
						Produce::inv_primitive(Emit::tree(), RETURN_BIP);
						Produce::down(Emit::tree());
							Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 0);
						Produce::up(Emit::tree());
					Produce::up(Emit::tree());
				Produce::up(Emit::tree());
			}
			@<Compile an optional mid-rulebook paragraph break@>;
			if (parameter_based) {
				Produce::inv_primitive(Emit::tree(), STORE_BIP);
				Produce::down(Emit::tree());
					Produce::ref_iname(Emit::tree(), K_value, Hierarchy::find(PARAMETER_VALUE_HL));
					Produce::val_symbol(Emit::tree(), K_value, p_s);
				Produce::up(Emit::tree());
			}
			Produce::inv_primitive(Emit::tree(), STORE_BIP);
			Produce::down(Emit::tree());
				Produce::ref_symbol(Emit::tree(), K_value, rv_s);
				Produce::inv_primitive(Emit::tree(), INDIRECT0_BIP);
				Produce::down(Emit::tree());
					Specifications::Compiler::emit_as_val(K_value, spec);
				Produce::up(Emit::tree());
			Produce::up(Emit::tree());

			Produce::inv_primitive(Emit::tree(), IF_BIP);
			Produce::down(Emit::tree());
				Produce::val_symbol(Emit::tree(), K_value, rv_s);
				Produce::code(Emit::tree());
				Produce::down(Emit::tree());
					Produce::inv_primitive(Emit::tree(), IF_BIP);
					Produce::down(Emit::tree());
						Produce::inv_primitive(Emit::tree(), EQ_BIP);
						Produce::down(Emit::tree());
							Produce::val_symbol(Emit::tree(), K_value, rv_s);
							Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 2);
						Produce::up(Emit::tree());
						Produce::code(Emit::tree());
						Produce::down(Emit::tree());
							Produce::inv_primitive(Emit::tree(), RETURN_BIP);
							Produce::down(Emit::tree());
								Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(REASON_THE_ACTION_FAILED_HL));
							Produce::up(Emit::tree());
						Produce::up(Emit::tree());
					Produce::up(Emit::tree());

					Produce::inv_primitive(Emit::tree(), RETURN_BIP);
					Produce::down(Emit::tree());
						Specifications::Compiler::emit_as_val(K_value, spec);
					Produce::up(Emit::tree());
				Produce::up(Emit::tree());
			Produce::up(Emit::tree());

			Produce::inv_primitive(Emit::tree(), STORE_BIP);
			Produce::down(Emit::tree());
				Produce::inv_primitive(Emit::tree(), LOOKUPREF_BIP);
				Produce::down(Emit::tree());
					Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(LATEST_RULE_RESULT_HL));
					Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 0);
				Produce::up(Emit::tree());
				Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 0);
			Produce::up(Emit::tree());
			break;
	}

@<End an action group in the rulebook@> =
	if (action_group_open) {
		switch (format) {
			case ROUTINE_RBF:
					Produce::up(Emit::tree());
					Produce::code(Emit::tree());
					Produce::down(Emit::tree());
						@<Compile an optional mid-rulebook paragraph break@>;
					Produce::up(Emit::tree());
				Produce::up(Emit::tree());
				break;
		}
		action_group_open = FALSE;
	}

@<Close the rulebook compilation@> =
	switch (format) {
		case ARRAY_RBF:
		case GROUPED_ARRAY_RBF:
			Emit::array_null_entry();
			Emit::array_end(save_array);
			break;
		case ROUTINE_RBF:
			Produce::inv_primitive(Emit::tree(), RETURN_BIP);
			Produce::down(Emit::tree());
				Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 0);
			Produce::up(Emit::tree());
			Routines::end(save_array);
			break;
	}

@<Compile an optional mid-rulebook paragraph break@> =
	if (entry_count > 0) {
		Produce::inv_primitive(Emit::tree(), IF_BIP);
		Produce::down(Emit::tree());
			Produce::val_iname(Emit::tree(), K_number, Hierarchy::find(SAY__P_HL));
			Produce::code(Emit::tree());
			Produce::down(Emit::tree());
				Produce::inv_call_iname(Emit::tree(), Hierarchy::find(RULEBOOKPARBREAK_HL));
				Produce::down(Emit::tree());
					Produce::val_symbol(Emit::tree(), K_value, forbid_breaks_s);
				Produce::up(Emit::tree());
			Produce::up(Emit::tree());
		Produce::up(Emit::tree());
	}

@

=
#ifdef IF_MODULE
action_name *RTRules::br_required_action(booking *br) {
	phrase *ph = Rules::get_defn_as_phrase(br->rule_being_booked);
	if (ph) return Phrases::Context::required_action(&(ph->runtime_context_data));
	return NULL;
}
#endif

