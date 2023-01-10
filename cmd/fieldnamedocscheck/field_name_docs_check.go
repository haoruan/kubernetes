/*
Copyright 2023 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"fmt"
	"os"
	"strings"

	flag "github.com/spf13/pflag"
	kruntime "k8s.io/apimachinery/pkg/runtime"
	"k8s.io/klog/v2"
)

var (
	typeSrc         = flag.StringP("type-src", "s", "", "From where we are going to read the types")
	internalTypeSrc = flag.StringP("internal-type-src", "i", "", "From where we are going to read the corresponding internal types")
)

func main() {
	flag.Parse()

	if *typeSrc == "" {
		klog.Fatalf("Please define -s flag as it is the api type file")
	}

	docsForTypes := kruntime.ParseDocumentationFrom(*typeSrc)

	if *internalTypeSrc == "" {
		for _, ks := range docsForTypes {
			for _, p := range ks[1:] {
				checkFieldNameAndDoc(ks[0].Name, p.Name, p.Doc, false)
			}
		}
		return
	}

	docsForInternalTypes := kruntime.ParseDocumentationFrom(*internalTypeSrc)

	// Convert dcosForInternalTypes from slice to map, in case
	// the order of structs or fields in internal types are different from those in staging/k8s.io
	docsForInternalTypesMap := make(map[string]map[string]string)
	for _, ks := range docsForInternalTypes {
		docsForInternalTypesMap[ks[0].Name] = make(map[string]string)
		for _, p := range ks[1:] {
			docsForInternalTypesMap[ks[0].Name][strings.ToLower(p.Name)] = p.Doc
		}
	}

	for _, ks := range docsForTypes {
		for _, p := range ks[1:] {
			checkFieldNameAndDoc(ks[0].Name, p.Name, docsForInternalTypesMap[ks[0].Name][strings.ToLower(p.Name)], true)
		}
	}
}

func checkFieldNameAndDoc(structName, fieldName, doc string, isInternalType bool) {
	pkg := "api"
	if isInternalType {
		pkg = "internal"
	}

	if doc != "" {
		fieldNameInDoc := strings.Fields(doc)[0]
		fieldNameInDoc = strings.Trim(fieldNameInDoc, "`")
		// Only check the field whose doc starts with the field name
		if strings.EqualFold(fieldName, fieldNameInDoc) && fieldName != fieldNameInDoc {
			fmt.Fprintf(os.Stderr, "In %s struct %s, field name is: %s, but in doc is: %s\n", pkg, structName, fieldName, fieldNameInDoc)
		}
	}
	// Some fields(see hack/.descriptions_failures) don't have documentation, so we skip them
}
