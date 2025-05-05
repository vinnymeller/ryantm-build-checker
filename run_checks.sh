#!/usr/bin/env bash

if [[ -z "${MAINTAINER_HANDLE}" ]]; then
	echo "Error: MAINTAINER_HANDLE environment variable is not set." >&2
	exit 1
fi

if [[ -z "${NIXPKGS_SRC_PATH}" ]]; then
	echo "Error: NIXPKGS_SRC_PATH environment variable is not set." >&2
	exit 1
fi

echo "Finding packages maintained by ${MAINTAINER_HANDLE}..."
nix-instantiate --eval --json --strict \
	--arg nixpkgsPath "${NIXPKGS_SRC_PATH}" \
	--argstr maintainer "${MAINTAINER_HANDLE}" \
	find_maintained.nix >maintained_packages.json

if ! jq -e . maintained_packages.json >/dev/null; then
	echo "Error: Failed to get a valid package list from find_maintained.nix" >&2
	cat maintained_packages.json
	exit 1
fi

echo "Found packages:"
jq -r '.[]' maintained_packages.json

jq -r '.[]' maintained_packages.json | while IFS= read -r pkg_name; do
	echo "--- Checking package: ${pkg_name} ---"
	python check_log.py "$pkg_name"
	exit_code=$?
	issue_title=""
	issue_body=""

	case $exit_code in
	0)
		echo "Check successful for ${pkg_name}."
		;;
	1)
		echo "Generic error checking ${pkg_name}. See script output above." >&2
		;;
	2)
		echo "Log page not found (404) for ${pkg_name}." >&2
		issue_title="Missing Log Page: ${pkg_name}"
		printf -v issue_body 'The r.ryantm log page could not be found for `%s`.\nURL: https://r.ryantm.com/log/%s\n\nThis might indicate that the package does not have an automated update script or it'\''s misconfigured.' "$pkg_name" "$pkg_name"
		# issue_body=$'The r.ryantm log page could not be found for `${pkg_name}`.\nURL: https://r.ryantm.com/log/${pkg_name}\n\nThis might indicate that the package does not have an automated update script or it\'s misconfigured.'
		;;
	3)
		echo "Build failure detected for ${pkg_name}." >&2
		issue_title="Build Failure Detected: ${pkg_name}"
		printf -v issue_body 'A build failure was detected in the latest r.ryantm log for `%s`.\n\nPlease check the log: https://r.ryantm.com/log/%s' "$pkg_name" "$pkg_name"
		# issue_body=$'A build failure was detected in the latest r.ryantm log for \`${pkg_name}\`.\n\nPlease check the log: https://r.ryantm.com/log/${pkg_name}'
		;;
	*)
		echo "Unknown exit code ${exit_code} from check_log.py for ${pkg_name}." >&2
		;;
	esac

	if [[ -n "$issue_title" ]]; then
		echo "Checking for existing open issues..."
		existing_issue_url=$(gh issue list --repo "$GITHUB_REPOSITORY" --state open --search "in:title \"$issue_title\"" --json url -q '.[0].url // empty')

		if [[ -n "$existing_issue_url" ]]; then
			echo "An existing open issue was found: $existing_issue_url"
		else
			echo "No existing open issue found. Creating a new issue..."
			gh issue create --repo "$GITHUB_REPOSITORY" \
				--title "$issue_title" \
				--body "$issue_body"
			echo "Issue created."
		fi
	fi
	echo "--- Finished checking ${pkg_name} ---"
done

echo "All checks complete."
