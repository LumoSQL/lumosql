/* eslint-env mocha */
import { strict as assert } from "assert";

import { column, join } from "../src/utils/presentation.mjs";

describe("column", function() {
  it("simple numbers", function() {
    assert.deepEqual(column(0), "A");
    assert.deepEqual(column(1), "B");
  });
});
describe("join", function() {
  it("one item", function() {
    const one = ["1"];
    assert.deepEqual(join(one.slice()), "1");
    assert.deepEqual(one, ["1"]);
  });
  it("two items", function() {
    assert.deepEqual(join(["1", "2"]), "1 and 2");
  });
  it("three items", function() {
    assert.deepEqual(join(["1", "2", "3"]), "1, 2 and 3");
  });
  it("four items", function() {
    assert.deepEqual(join(["1", "2", "3", "4"]), "1, 2, 3 and 4");
  });
});
