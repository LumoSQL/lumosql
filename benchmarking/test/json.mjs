/* eslint-env mocha */

import { strict as assert } from "assert";

import {
  getRuns,
  getTests,
  getVersions,
  median,
  unconvert
} from "../src/utils/json.mjs";

describe("getRuns", function() {
  it("gets a single run name", function() {
    assert.deepEqual(getRuns([["A", []]]), ["A"]);
  });
  it("gets multiple run names", function() {
    assert.deepEqual(
      getRuns([
        ["A", []],
        ["B", []]
      ]),
      ["A", "B"]
    );
  });
  it("gets multiple run names in numeric order", function() {
    assert.deepEqual(
      getRuns([
        ["2", []],
        ["1", []],
        ["10", []]
      ]),
      ["1", "2", "10"]
    );
  });
});

describe("getVersions", function() {
  it("gets a single version name", function() {
    assert.deepEqual(getVersions([["run1", [["version1", []]]]]), ["version1"]);
  });
  it("works across multiple runs", function() {
    assert.deepEqual(
      getVersions([
        ["run1", [["version1", []]]],
        ["run2", [["version1", []]]]
      ]),
      ["version1"]
    );
  });
  it("gets multiple version names", function() {
    assert.deepEqual(
      getVersions([
        [
          "run1",
          [
            ["version1", []],
            ["version2", []]
          ]
        ]
      ]),
      ["version1", "version2"]
    );
  });
});
describe("getTests", function() {
  it("gets a single test name", function() {
    assert.deepEqual(
      getTests([
        ["run1", [["version1", [["test1", 1]]]]],
        ["run2", [["version1", [["test1", 1]]]]]
      ]),
      ["test1"]
    );
  });
  it("gets multiple test names", function() {
    assert.deepEqual(
      getTests([
        [
          "run1",
          [
            [
              "version1",
              [
                ["test1", 1],
                ["test2", 2]
              ]
            ]
          ]
        ],
        ["run2", [["version1", [["test1", 1]]]]]
      ]),
      ["test1", "test2"]
    );
  });
});

describe("unconvert", function() {
  it("a simple array to a map", function() {
    const result = unconvert([["A", 1]]);
    assert.deepEqual(result, new Map([["A", 1]]));
  });
  it("a nested array to a map", function() {
    const result = unconvert([
      ["A", 1],
      ["B", [["C", 2]]]
    ]);
    assert.deepEqual(
      result,
      new Map([
        ["A", 1],
        ["B", new Map([["C", 2]])]
      ])
    );
  });
});

describe("median", function() {
  it("middle number", function() {
    assert.deepEqual(median([1, 2, 3]), 2);
  });
  it("average of two", function() {
    assert.deepEqual(median([1, 2]), 1.5);
  });
});
