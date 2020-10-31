/* eslint-env mocha */
/* global cy, expect */
import { getVersions } from "../../src/utils/json.mjs";

describe("/", () => {
  beforeEach(() => {
    cy.visit("/");
  });
  it("has the correct <h1>", () => {
    cy.contains("h1", "LumoSQL Benchmarking");
  });
  it("links to /data.json", () => {
    cy.contains("data extracted")
      .get("a")
      .should("have.attr", "href", "/data.json");
  });
});
describe("/data.json", () => {
  it("returns JSON", () => {
    cy.request("/data.json")
      .its("headers")
      .its("content-type")
      .should("include", "application/json");
  });
  it("should have two keys", () => {
    cy.request("/data.json")
      .its("body")
      .should("have.length", 2);
  });
  it("versions should be in the correct order", () => {
    const order = [
      "3.7.17 2013-05-20 00:56:22 118a3b35693b134d56ebd780123b7fd6f1497668",
      "3.30.1 2019-10-10 20:19:45 18db032d058f1436ce3dea84081f4ee5a0f2259ad97301d43c426bc7f3df1b0b",
      "3.7.17 c896ea8 LMDB_0.9.9  7449ca6",
      "3.7.17 c896ea8 LMDB_0.9.16 5d67c6a"
    ];
    cy.request("/data.json")
      .its("body")
      .then(runs => expect(getVersions(runs)).to.deep.equal(order));
  });
});
