SHELL := /bin/bash

ios_versions := $(addprefix ios,8.0 8.1 8.2 8.3 8.4 9.0 9.1 9.2 9.3 10.0 10.1 10.2 10.3 \
	11.0 11.1 11.2 11.3 11.4 12.0 12.1 12.2 12.4 13.0 13.1 13.2 13.3 13.4 13.5 13.6 13.7 \
	14.0 14.1 14.2 14.3 14.4 14.5 14.6 14.7 14.8 15.0 15.1 15.2 15.3 15.4 15.5 15.6 15.7 \
    16.0 16.1 16.2 16.3 16.4 16.5 16.6 17.0 17.1 17.2 17.3 17.4 17.5 17.6 17.7 18.0 18.1 \
	18.2 18.3 18.4 18.5)
ios_latest := $(lastword $(ios_versions))
android_versions := $(addprefix android,10 15 16 17 18 19 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36)
all_versions := $(ios_versions) $(android_versions)
android_latest := $(lastword $(android_versions))

ios ?= $(ios_latest)
android ?= $(android_latest)
combo := $(ios)-$(android)

dist_regex_py := dist/$(combo)-common-glyphs-regex-py.txt
dist_regex_js := $(dist_regex_py:%-py.txt=%-js.txt)
dist_regex_dart := $(all_versions:%=dist/%.g.dart)
dist_decimal := $(foreach _,$(all_versions),dist/$(_)-glyphs-decimal.txt)

.PHONY: regex
regex: ## Generate regex for latest iOS and Android versions
regex: $(dist_regex_py) $(dist_regex_js)

.PHONY: decimal
decimal: ## Generate glyphs for all platforms in decimal format
decimal: $(dist_decimal)

.PHONY: dart
dart: ## Generate Dart regex for all platforms
dart: $(dist_regex_dart)

# Generate in /data but move to /dist
dist/%: data/% | dist
	mv $(<) $(@)

dist:
	mkdir -p $(@)

.PHONY: clean
clean: ## Clean temporary files
clean:
	rm -rf dist

.env:
	python3 -m venv $(@)
	$(@)/bin/pip install FontTools


### Data munging recipes

intersection = comm -12 <(cut -d ' ' -f 1 $(<)) <(cut -d ' ' -f 1 $(word 2,$(^))) \
	$(foreach _,$(wordlist 3,$(words $(^)),$(^)), | comm -12 - <(cut -d ' ' -f 1 $(_)))

data/$(combo)-common-glyphs.txt: data/$(ios)-glyphs.txt data/$(android)-glyphs.txt
	$(intersection) >$(@)

%-decimal.txt: %.txt
	cat $(^) \
		| cut -d ' ' -f 1 \
		| cut -d '+' -f 2 \
		| while read cp; do echo $$((16#$$cp)); done >$(@)

%-regex-py.txt: %.txt | .env
	cat $(^) | .env/bin/python codepoints2regex.py > $(@)

%-regex-js.txt: %.txt | .env
	cat $(^) | .env/bin/python codepoints2regex.py js > $(@)

%.g.dart: %-glyphs-regex-js.txt
	identifier=$$(echo $(*) | sed -E -e 's!.*/|-.*!!g;s![^a-zA-Z0-9$$]!_!g'); \
		printf "final RegExp %sPattern = RegExp(\n  '%s',\n  unicode: true,\n);\n" $$identifier $$(cat $(<)) > $(@)

### Data collection

# ios%-raw.txt files are generated by the GlyphTester app on an iOS device or
# simulator. This was the initial approach but is tricky because it's hard to
# distinguish between an error in getting the glyph name and codepoints that are
# supported but have no glyph.

ios%-app-glyphs.txt: ios%-raw.txt
	grep -vE "lastresort(template|privateplane16|privateuse)" $(^) >$(@)

# Instead we can inspect the fonts included in the simulator runtime (minus
# LastResort) for a more accurate accounting. Xcode versions, iOS versions, and
# simulator runtime font locations are as follows:
#
# case
#  iOS 8.0: Xcode 6.0.1
#  iOS 8.1: Xcode 6.1.1
#  iOS 8.2: Xcode 6.2
#  iOS 8.3: Xcode 6.3.2
#  iOS 8.4: Xcode 6.4
#  iOS 9.0: Xcode 7.0.1
#  iOS 9.1: Xcode 7.1.1
#  iOS 9.2: Xcode 7.2.1
#  iOS 9.3: Xcode 7.3.1
#  iOS 10.0: Xcode 8.0
#  iOS 10.1: Xcode 8.1
#  iOS 10.2: Xcode 8.2.1
#  iOS 10.3: Xcode 8.3.3
#   Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Fonts
# case
#  iOS 11.0: Xcode 9.0.1
#  iOS 11.1: Xcode 9.1
#  iOS 11.2: Xcode 9.2
#  iOS 11.3: Xcode 9.3.1
#  iOS 11.4: Xcode 9.4.1
#  iOS 12.0: Xcode 10.0
#  iOS 12.1: Xcode 10.1
#  iOS 12.2: Xcode 10.2.1
#  iOS 12.4: Xcode 10.3
#   Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/Fonts
# case
#  iOS 13.0: Xcode 11.0
#  iOS 13.1: Xcode 11.1
#  iOS 13.2: Xcode 11.2.1
#  iOS 13.3: Xcode 11.3
#  iOS 13.4: Xcode 11.4
#  iOS 13.5: Xcode 11.5
#   Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/Fonts
# case
#  iOS 17.0: Xcode 15.0
#   Install iOS runtime separately; contents are mounted at /Library/Developer/CoreSimulator/Volumes/
# case
#  iOS 18.0: Xcode 16.0
#   Just PingFangUI.ttc has moved to RuntimeRoot/System/Library/PrivateFrameworks/FontServices.framework/CorePrivate

ios_runtime_volumes := /Library/Developer/CoreSimulator/Volumes
ios_fonts = $(wildcard $(ios_runtime_volumes)/*/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS*.simruntime/Contents/Resources/RuntimeRoot/System/Library/Fonts)
ios_private_fonts = $(wildcard $(ios_runtime_volumes)/*/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS*.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/FontServices.framework)
ios_plist = $(wildcard $(ios_runtime_volumes)/*/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS*.simruntime/Contents/Info.plist)

ios%-glyphs.txt: | .env
	$(if $(ios_plist),,$(error No iOS simulator runtime found))
	$(info Gathering codepoints for $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$(ios_plist)"))
	find "$(ios_fonts)" "$(ios_private_fonts)" \( -name '*.ttf' -o -name '*.ttc' -o -name '*.otf' \) \
		! -name 'LastResort.*' -print0 \
			| xargs -0 .env/bin/python list-ttf-chars.py >$(@)

.PHONY: ios-fonts
ios-fonts: | .env
	$(if $(ios_plist),,$(error No iOS simulator runtime found))
	$(info Listing fonts in $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$(ios_plist)"))
	find "$(ios_fonts)" "$(ios_private_fonts)" \( -name '*.ttf' -o -name '*.ttc' -o -name '*.otf' \) \
		! -name 'LastResort.*' -print0 \
			| xargs -0 basename

# Through SDK 25, android%-glyphs.txt are generated from the files in the /fonts
# directory of the x86 system.img for that platform version. Note that the fonts
# included in the "Platform" package at
# $ANDROID_HOME/platforms/android-%/data/fonts is a mere subset of the fonts
# found on the system.img and is notably missing e.g. extended CJK coverage.

data/android%-glyphs.txt: vendor/android-%/fonts | .env
	.env/bin/python list-ttf-chars.py $(<)/* >$(@)

vendor/android-%/fonts: $(ANDROID_HOME)/system-images/android-%/default/x86/system.img
	if [ ! -d $(@) ]; then ext4fuse $(<) $(@D); fi

# Mounting system.img as ext4 only works for up to SDK 25. SDK 26 and later are
# a different format that I can't figure out how to mount. Instead launch an AVD
# and do `make avd-fonts` to dump the fonts.

avd_sdk_version = $(shell adb shell getprop ro.build.version.sdk)

.PHONY: avd-fonts
avd-fonts: ## Dump fonts from a running Android Virtual Device
avd-fonts:
	mkdir -p vendor/android-$(avd_sdk_version)
	adb pull /system/fonts vendor/android-$(avd_sdk_version)/

.PHONY: help
help: ## Show this help text
	$(info usage: make [target])
	$(info )
	$(info Available targets:)
	@awk -F ':.*?## *' '/^[^\t].+?:.*?##/ \
         {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
