.PHONY: check syntax links test clean

check: syntax links

syntax:
	@echo "== سلامة صياغة السكربتات =="
	@fail=0; for f in $$(find scripts -name '*.sh' | sort); do \
		if bash -n "$$f"; then echo "  ✔ $$f"; else echo "  ✘ $$f"; fail=1; fi; \
	done; exit $$fail

links:
	@echo "== فحص الروابط والمراسي =="
	@python3 tools/check-links.py

test: check
	@echo "== تحليل سجل شحن تجريبي =="
	@bash scripts/diagnostics/charge-report.sh --all tests/fixtures/sample-charge.csv

clean:
	@rm -f /tmp/.nabu-ufs-test
