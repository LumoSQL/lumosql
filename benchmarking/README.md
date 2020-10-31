# Benchmarking

## Quick start

### Create the benchmarking data

1. Start with the root of this repository as the current working directory
2. Make sure you have successfully built the repository once e.g. with a simple
   `make` command
3. Set the `DATA` environment variable to where you want to store the
   benchmarking data e.g. `export DATA=/var/srv/data`
4. Start the benchmarking, the shell script below will produce three runs:

   ```sh
   test -d "$DATA" || echo '$DATA is not set properly'
   path="$PWD"
   cd "$DATA"
   date &&
   seq 1 5 | while read i ; do
     test -d "$i" || git clone "$path" "$i" || break
     test -d "$i/src-SQLite" || git -C "$i" clone "$path/src-SQLite" || break
     test -d "$i/src-lmdb" || git -C "$i" clone "$path/src-lmdb" || break
     make -C "$i" benchmark || break
   done &&
   date
   ```

### Summarise and publish the benchmarking data

The steps below summarise and publish the benchmarking results on GitHub pages.
This process use Node JS and a JavaScript framework called svelte:

- Make sure you have Node JS 12 or higher installed, the [official instructions]
  may help
- Run `npm install` in this `benchmarking` directory

Each time you wish to produce a table, set the `DATA` environment variable to
where you want to store the benchmarking data e.g. `export DATA=/var/srv/data`,
as above.

Then start with this directory, `benchmarking`, as the current directory:

```sh
test -d "$DATA" || echo '$DATA is not set properly'
npm run dev                      # check everything looks OK
test -d gh-pages || git worktree add gh-pages gh-pages
npm run gh-pages
cd gh-pages
python3 -m http.server           # check it looks good or another http server
git commit
git push
```

Exporting the `TITLE` environment variable changes the title and heading text in
the HTML.

Note that if data is left set then the tests on the JavaScript code will fail —
`unset DATA`.

[official instructions]: https://nodejs.org/en/download/package-manager

## Terminology

1. Several runs make up a data **set**
2. A **run** includes separate reports on different versions, it can be
   represented as a directory
3. A **report** shows the results of different tests for a single version, it
   can be represented as an HTML file
4. This benchmarking compares different **versions** for example upstream SQLite
   3.7.17 is a version
5. Comparisons are made across different **tests**, tests typically have a name
   and a value

## Design choices

This benchmarking project:

- uses ES Modules where possible
- avoids a module bundler like "rollup" as much as possible for simplicity
- has 100% test coverage for `src/utils/`
- formats everything with https://prettier.io
- checks JavaScript and Svelte code with https://eslint.org

## Prerequisites

- Node JS >= 12, for ES Modules support

## Tests

This project uses the [Mocha](https://mochajs.org) test framework. Mocha's
support for ES Modules with Node is a
[work in progress](https://github.com/mochajs/mocha/pull/4038). The version of
mocha specified in `package.json` is an experimental release with support for ES
Modules.
