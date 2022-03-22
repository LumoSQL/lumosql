<!-- Copyright 2022 The LumoSQL Authors, see LICENSES/MIT -->

<!-- SPDX-License-Identifier: MIT -->
<!-- SPDX-FileCopyrightText: 2020 The LumoSQL Authors -->
<!-- SPDX-ArtifactOfProjectName: LumoSQL -->
<!-- SPDX-FileType: Documentation -->
<!-- SPDX-FileComment: Original by Dan Shearer, December 2019 -->

This directory contains compatibility tests for the Lumo hidden columns used
for example to implement the `rowsum` extension.

To run these tests, use the `EXTRA_BUILDS` option to specify the version
of sqlite3 to use to generate the metadata, for example:

```
make test LUMO_TEST_DIR=alternative-tests/metadata EXTRA_BUILDS=latest++rowsum-on TARGETS=all
```

would first build the latest version of sqlite with the rowsum option enabled,
then run the `metadata` tests using the sqlite specified by `EXTRA_BUILDS` to
generate the metadata, and the sqlite versions specified by `TARGETS` to
run the compatibility tests

This is work in progress - when we implement full Lumo metadata we'll want
to add to it.

