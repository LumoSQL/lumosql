/* eslint-env mocha */

import { strict as assert } from "assert";
import { promises as fsPromises } from "fs";

import {
  compare,
  convert,
  report,
  run,
  set,
  times,
  version
} from "../src/utils/html.mjs";

// Manually parsed results matching reports in test/data/1
const path = "test/data/1/SQLite-3.30.1.html"; // path for expected report
const expected = new Map();
expected.set(
  "3.30.1 2019-10-10 20:19:45 18db032d058f1436ce3dea84081f4ee5a0f2259ad97301d43c426bc7f3df1b0b",
  [
    ["Test 1: 1000 INSERTs", 6.348],
    ["Test 2: 25000 INSERTs in a transaction", 0.11],
    ["Test 3: 100 SELECTs without an index", 0.176],
    ["Test 4: 100 SELECTs on a string comparison", 0.433],
    ["Test 5: 5000 SELECTs", 6.16],
    ["Test 6: 1000 UPDATEs without an index", 0.099],
    ["Test 7: 25000 UPDATEs with an index", 22.394],
    ["Test 8: 25000 text UPDATEs with an index", 22.455],
    ["Test 9: INSERTs from a SELECT", 0.069],
    ["Test 10: DELETE without an index", 0.087],
    ["Test 11: DELETE with an index", 0.041],
    ["Test 12: A big INSERT after a big DELETE", 0.05],
    ["Test 13: A big DELETE followed by many small INSERTs", 0.056],
    ["Test 14: DROP TABLE", 0.059]
  ]
);
const versions = [
  "3.7.17 2013-05-20 00:56:22 118a3b35693b134d56ebd780123b7fd6f1497668",
  "3.30.1 2019-10-10 20:19:45 18db032d058f1436ce3dea84081f4ee5a0f2259ad97301d43c426bc7f3df1b0b",
  "3.7.17 c896ea8 LMDB_0.9.9  7449ca6",
  "3.7.17 c896ea8 LMDB_0.9.16 5d67c6a"
];

describe("times", function() {
  it("Extracts one name and time from HTML", function() {
    assert.deepEqual(
      times(`
          <h2>Test 2: 25000 INSERTs in a transaction</h2>
          <blockquote>
          ✂
          </blockquote><table border=0 cellpadding=0 cellspacing=0>
          <tr><td>✂</td><td align="right">&nbsp;&nbsp;&nbsp;0.110</td></tr>
          </table>
          `),
      [["Test 2: 25000 INSERTs in a transaction", 0.11]]
    );
  });
  it("Extracts names and times from a file", async function() {
    const html = await fsPromises.readFile(path, { encoding: "utf8" });
    assert.deepEqual(times(html), expected.values().next().value);
  });
});

describe("version", function() {
  it("Extracts a single version from an HTML string", function() {
    assert.equal(
      version(`
        <table border="0" cellpadding="0" cellspacing="0">
        <tr><td>3.7.17 2013-05-20 00:56:22 118a3b35693b134d56ebd780123b7fd6f1497668</td><td align="right">&nbsp;&nbsp;&nbsp;10.548</td></tr>
        </table>
        `),
      "3.7.17 2013-05-20 00:56:22 118a3b35693b134d56ebd780123b7fd6f1497668"
    );
  });
  it("Extracts a single version from an HTML file", async function() {
    const html = await fsPromises.readFile(path, { encoding: "utf8" });
    assert.equal(expected.keys().next().value, version(html));
  });
  it("Throws an exception on multiple versions", function() {
    assert.throws(
      () =>
        version(`
          <table border="0" cellpadding="0" cellspacing="0">
          <tr><td>3.7.17 2013-05-20 00:56:22 118a3b35693b134d56ebd780123b7fd6f1497668</td><td align="right">&nbsp;&nbsp;&nbsp;10.548</td></tr>
          <tr><td>3.30.1 2019-10-10 20:19:45 18db032d058f1436ce3dea84081f4ee5a0f2259ad97301d43c426bc7f3df1b0b</td><td align="right">&nbsp;&nbsp;&nbsp;6.348</td></tr>
          </table>
          `),
      /number of versions/
    );
  });
});

describe("report", function() {
  it("Parses a single report as expected", async function() {
    assert.deepEqual(await report(path), expected);
  });
});

describe("run", function() {
  let result;

  before("Parse test/data/1", async function() {
    result = await run("test/data/1");
  });

  it("Finds four reports", function() {
    assert.deepEqual(result.size, 4);
  });

  it("Parses one report matching the manually parsed data", function() {
    assert.deepEqual(
      result.get(expected.keys().next().value),
      expected.values().next().value
    );
  });

  it("Parses version numbers matching those found manually", function() {
    assert.deepEqual(new Set(Array.from(result.keys())), new Set(versions));
  });
});

describe("set", function() {
  let result;

  before("Parse test/data/", async function() {
    result = await set("test/data/");
  });

  it("Finds one run", async function() {
    assert.deepEqual(result.size, 2);
  });

  it("Parses version numbers matching those found manually", function() {
    assert.deepEqual(
      new Set(Array.from(result.get("1").keys())),
      new Set(versions)
    );
    assert.deepEqual(
      new Set(Array.from(result.get("2").keys())),
      new Set(versions)
    );
  });
});

describe("convert", function() {
  it("a simple map to an array", function() {
    const result = convert(new Map([["A", 1]]));
    assert.deepEqual(result, [["A", 1]]);
  });
  it("a nested map to an object", function() {
    const result = convert(
      new Map([
        ["A", 1],
        ["B", new Map([["C", 2]])]
      ])
    );
    assert.deepEqual(result, [
      ["A", 1],
      ["B", [["C", 2]]]
    ]);
  });
});

describe("compare", function() {
  it("simple strings", function() {
    assert.deepEqual(compare("A", "A"), 0);
    assert.deepEqual(compare("1", "2"), -1);
    assert.deepEqual(compare("2", "1"), 1);
    assert.deepEqual(compare("1", "1"), 0);
    assert.deepEqual(compare("1.11", "1.12"), -1);
    assert.deepEqual(compare("1.11", "1.12.1"), -1);
    assert.deepEqual(compare("1.11.1", "1.11"), 1);
    assert.deepEqual(compare("1.11", "1.11.1"), -1);
  });
  it("special case versions containing LMDB", function() {
    assert.deepEqual(compare("1", "2"), -1); //neither
    assert.deepEqual(compare("1 LMDB", "1 LMDB"), 0); //both =
    assert.deepEqual(compare("1 LMDB", "2 LMDB"), -1); //both >
    assert.deepEqual(compare("B LMDB", "A LMDB"), 1); //both <
    assert.deepEqual(compare("1 LMDB", "2"), 1); //first
    assert.deepEqual(compare("1", "2_LMDB"), -1); //second
  });
  it("realistic strings", function() {
    assert.deepEqual(
      compare(
        "3.7.17 c896ea8 LMDB_0.9.16 5d67c6a",
        "3.7.17 c896ea8 LMDB_0.9.9 7449ca6"
      ),
      1
    );
  });
  it("maps on the first key", function() {
    assert.deepEqual(
      compare(
        new Map([["3.7.17 c896ea8 LMDB_0.9.16 5d67c6a", undefined]]),
        new Map([["3.7.17 c896ea8 LMDB_0.9.9 7449ca6", undefined]])
      ),
      1
    );
  });
  it("idempotent on realistic versions", function() {
    const copy = versions.slice();
    copy.sort(compare);
    assert.deepEqual(copy, versions);
  });
});
