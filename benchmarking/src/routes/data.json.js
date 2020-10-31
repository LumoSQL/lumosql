/* eslint-env node */
import { convert, set } from "../utils/html.mjs";

const path = process.env.DATA || "test/data";

export async function get(req, res) {
  const data = await set(path);
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify(convert(data)));
}
