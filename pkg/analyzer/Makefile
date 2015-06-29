# Makefile for running DEP30 Analyzer tests and original analyzer tests.
#-------------------------------------------------------------------------------
# WHAT YOU NEED TO CONFIGURE:
#
# - DART_SDK is set in environment to point to a deployed SDK.
# - ORIG_SDK_PROJ: path to a local copy of the original/official Dart SDK GIT
#   project found at https://github.com/dart-lang/sdk.

ORIG_SDK_PROJ?=$(HOME)/git-sdk/sdk

#
# Variables you might need to customize:
#

# Path to the DEP 30 SDK GIT project folder. The assumption is that this Makefile
# is in the pkg/analyzer folder of this SDK.
NEW_SDK_PROJ?=../../sdk

# Path to a tmp directory
TMP?=~/tmp

# Other variables:

TEST_DIR?=test

#===============================================================================

default: test comp

#-------------------------------------------------------------------------------
# DEP30 specific tests (in NNBD and nullable-by-default modes)

test: info nn nu

info:;	@$(DART_SDK)/bin/dart --version

nn:;	@echo NNBD
	@-$(DART_SDK)/bin/dart -c -Dcom.google.dart.sdk=$(DART_SDK) -DDEP_NNBD=1 \
		$(TEST_DIR)/generated/nullity_test.dart \
		> $(TMP)/nullity_test_NNBD.txt 2>&1 
	@grep -E 'FAIL|ERR|passed' $(TMP)/nullity_test_NNBD.txt

nu:;	@echo NuBD
	@-$(DART_SDK)/bin/dart -c -Dcom.google.dart.sdk=$(DART_SDK) \
		$(TEST_DIR)/generated/nullity_test.dart \
		> $(TMP)/nullity_test_NuBD.txt 2>&1 
	@grep -E 'FAIL|ERR|passed' $(TMP)/nullity_test_NuBD.txt

out:;	@cat $(TMP)/nullity_test_NNBD.txt

#-------------------------------------------------------------------------------
# Original Analyzer full test suite.

comp:  aa orig diff
compc: aa diff

# DEP 30 analyzer over full suite.

aa:
	@echo Testing from $(PWD)
	@-mv $(TMP)/test_all_nubd.txt $(TMP)/test_all_nubd-prev.txt
	@-$(DART_SDK)/bin/dart -c -Dcom.google.dart.sdk=$(NEW_SDK_PROJ) \
		$(TEST_DIR)/test_all.dart \
		> $(TMP)/test_all_nubd.txt 2>&1 
	@-grep -E 'FAIL|ERR|passed' $(TMP)/test_all_nubd.txt \
		| tee $(TMP)/test_all_nubd_summary.txt
	@echo

# Original analyzer over full suite

orig:
	@echo Testing from $(ORIG_SDK_PROJ)/pkg/analyzer
	@-cd $(ORIG_SDK_PROJ)/pkg/analyzer; \
		$(DART_SDK)/bin/dart -c $(TEST_DIR)/test_all.dart \
		> $(TMP)/test_all_dartc.txt 2>&1 
	@-grep -E 'FAIL|ERR|passed' $(TMP)/test_all_dartc.txt \
		| tee $(TMP)/test_all_dartc_summary.txt
	@echo

# Output, diff or full file

diff:
	diff $(TMP)/test_all_dartc_summary.txt $(TMP)/test_all_nubd_summary.txt

outall:
	cat $(TMP)/test_all.txt

