/**
 * Map a number to a letter
 * @param {integer} number The number to map
 */
export function column(number) {
  return String.fromCharCode("A".charCodeAt(0) + number);
}
/**
 * Join elements with commas and "and"
 * @param {array} input The elements to join
 */
export function join(input) {
  let tail = input[input.length - 1];
  let head = input.slice(0, -1).join(", ");
  return head + (head ? " and " : "") + tail;
}
