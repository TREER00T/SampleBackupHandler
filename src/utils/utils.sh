#!/bin/bash

# Colors
red=$(tput setaf 1)
yellow=$(tput setaf 3)

# Helper Functions
has_exist_command() {
	if ! command -v "$1" &>/dev/null; then
		return 1
	fi
}
