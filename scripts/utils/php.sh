#!/usr/bin/env bash

php_checkSyntax() {
	local target_dir=${1:-'.'}

	for php in $(find $target_dir -name "*.php" -not -path '*vendor*' -type f); do
		if ! php -l "$php" >/dev/null 2>&1; then
			error "PHP syntax error found. Filename $php"
		fi
	done
}