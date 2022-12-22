# Example option files for batch-benchmark

This directory contains 3 example "option" files for the batch-benchmark tool.

They will need to be modified to match local configuration, in particular
options.03.storage need to match the reality of the system it runs on.

To build all necessary combinations of versions and build-time options:

  perl tool/batch-benchmark doc/examples/options.* build

To run lots of benchmarks:

  perl tool/batch-benchmark doc/examples/options.* benchmark

