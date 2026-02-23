# Makefile içeriği
.PHONY: setup

setup:
	pip install -r requirements.txt
	@echo "Environment is ready! Don't forget to configure your dbt profiles."