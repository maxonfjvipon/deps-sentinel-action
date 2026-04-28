# SPDX-FileCopyrightText: Copyright (c) 2026 Max Trunnikov
# SPDX-License-Identifier: MIT

.PHONY: all test lint

all: lint test

lint:
	shellcheck src/run.sh test/fake/gh

test:
	bats test/
