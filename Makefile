.PHONY: test test-unit test-integration test-quick examples

test:
	bash ./scripts/qa/reliability-audit.sh

test-unit:
	bash ./scripts/qa/reliability-audit.sh --unit-only

test-integration:
	bash ./scripts/qa/reliability-audit.sh --with-integration

test-quick:
	bash ./scripts/qa/reliability-audit.sh --quick

examples:
	bash ./scripts/qa/validate-examples.sh
