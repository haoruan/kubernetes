#!/usr/bin/env bash

# Copyright 2023 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script checks API-related files for mismatch in descriptions and field names
# list of structs and fields that are mismatched.
# Usage: `hack/verify-fieldname-docs.sh`.

set -o errexit
set -o nounset
set -o pipefail

KUBE_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
source "${KUBE_ROOT}/hack/lib/init.sh"
source "${KUBE_ROOT}/hack/lib/util.sh"

kube::golang::setup_env

#make -C "${KUBE_ROOT}" WHAT=cmd/fieldnamedocscheck

# Find binary
fieldnamedocscheck=$(kube::util::find-binary "fieldnamedocscheck")

result=0

# The internal api files are not in pkg/apis for following groups, needs special handling
special_groups=(
    apiextensions-apiserver
    kube-aggregator
)

internal_api_dirs=()
while read -r file ; do
	internal_api_dirs+=("${file}")
done < <(ls -d pkg/apis/*/)

for internal_api_dir in "${internal_api_dirs[@]}"; do
	package="${internal_api_dir%"/"}"
	group_dirname="${package#"pkg/apis/"}"
    internal_api_file="${internal_api_dir}types.go"

    echo "Checking ${group_dirname} group"

    versioned_api_dirs=()
    while read -r file ; do
        versioned_api_dirs+=("${file}")
    done < <(find . -wholename "./staging/src/k8s.io/api/${group_dirname}/v*/types.go")

    if [ ${#versioned_api_files[@]} -ne 0 ]; then
        if [ -f ${internal_api_file} ]; then
            fieldnamedocscheck -s ${versioned_api_files[0]} -i ${internal_api_file} || result=$?
        else
            fieldnamedocscheck -s ${versioned_api_files[0]} || result=$?
        fi

        for versioned_api_file in "${versioned_api_files[@]:1}"; do
            fieldnamedocscheck -s ${versioned_api_file} || result=$?
        done
    fi
done

for group in "${special_groups[@]}"; do
    # The first one is internal api file, the other two are versioned api files
    api_files=()
    while read -r file ; do
        api_files+=("${file}")
    done < <(find . -wholename "./staging/src/k8s.io/${group}/pkg/apis/*/types.go")

	package="${api_files[0]%"/types.go"}"
	group_dirname="${package#"./staging/src/k8s.io/${group}/pkg/apis/"}"

    echo "Checking ${group_dirname}" group

    if [ ${#versioned_api_files[@]} -eq 3 ]; then
        fieldnamedocscheck -s ${api_files[1]} -i ${api_files[0]} || result=$?
        fieldnamedocscheck -s ${api_files[2]} || result=$?
    fi
done

exit ${result}