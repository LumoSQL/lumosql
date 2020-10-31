import { promises as fsPromises } from "fs";
import path from "path";

import cheerio from "cheerio";

/**
 * Extract the version number from HTML
 * @param {string|function} html A string or the result of a call to cheerio.load
 */
export function version(html) {
  const $ = typeof html === "string" ? cheerio.load(html) : html;
  let versions = new Set(
    $("td:not([align])")
      .map((index, element) => $(element).text())
      .toArray()
  );

  if (versions.size !== 1) {
    throw "Wrong number of versions in input";
  }

  return versions.values().next()["value"];
}

/**
 * Extract the names and times from HTML
 * @param {string|function} html A string or the result of a call to cheerio.load
 */
export function times(html) {
  const $ = typeof html === "string" ? cheerio.load(html) : html;
  const result = [];
  $("h2").each(function(index, element) {
    const h2 = $(element);
    const td = h2
      .nextAll("table")
      .first()
      .find("td[align=right]");
    result[index] = [h2.text(), Number.parseFloat(td.text())];
  });
  return result;
}

/**
 * Data from a file
 * @param file {string} A path to a file containing a report
 */
export async function report(file) {
  const html = await fsPromises.readFile(file, { encoding: "utf8" });
  const $ = cheerio.load(html);

  // https://github.com/bcoe/c8/issues/135 for explanation of ignore below
  /* c8 ignore next */
  return new Map([[version($), times($)]]);
}

/**
 * Parse a run from a directory
 * @param directory {string} A path to a directory containing reports
 */
export async function run(directory) {
  const filenames = await fsPromises.readdir(directory);
  const paths = filenames
    .filter(i => i.endsWith("html"))
    .map(i => path.join(directory, i));
  const reports = await Promise.all(paths.map(report));
  reports.sort(compare);
  let output = new Map();
  reports.forEach(report => (output = new Map([...output, ...report])));
  // https://github.com/bcoe/c8/issues/135 for explanation of ignore below
  /* c8 ignore next */
  return output;
}

/**
 * Parse a set of runs from a directory
 * @param root {string} A path to a directory containing reports
 */
export async function set(root) {
  const entries = await fsPromises.readdir(root, { withFileTypes: "true" });
  const directories = entries.filter(i => i.isDirectory()).map(i => i.name);
  const runs = new Map();
  for (const directory of directories) {
    const i = await run(path.join(root, directory));
    runs.set(directory, i);
  }
  // https://github.com/bcoe/c8/issues/135 for explanation of ignore below
  /* c8 ignore next */
  return runs;
}
/**
 * Recursively converts a map to objects suitable for JSON encoding
 * @param input {Map} To convert
 */
export function convert(input) {
  const result = [];
  input.forEach((value, key) => {
    if (value instanceof Map) result.push([key, convert(value)]);
    else result.push([key, value]);
  });
  return result;
}
/**
 * Comparison function to be used on LumoSQL version numbers
 * @param a {string|Map}
 * @param b {string|Map}
 */
export function compare(a, b) {
  const [a_array, b_array] = [a, b].map(i => {
    if (i instanceof Map) i = i.keys().next()["value"];
    return i
      .replace(/[._]/g, " ")
      .split(/ +/)
      .map(s => {
        const parsed = Number(s);
        return isNaN(parsed) ? s : parsed;
      });
  });
  const length = Math.min(a_array.length, b_array.length);

  if (a_array.includes("LMDB") && !b_array.includes("LMDB")) return 1;
  if (b_array.includes("LMDB") && !a_array.includes("LMDB")) return -1;

  for (let i = 0; i < length; i++) {
    if (a_array[i] > b_array[i]) return 1;
    if (a_array[i] < b_array[i]) return -1;
  }
  if (a_array.length == b_array.length) return 0;
  else if (a_array.length < b_array.length) return -1;
  else return 1;
}
