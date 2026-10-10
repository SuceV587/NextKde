// Test harness for PayloadArray.mjs — run with: node test_payload_array.mjs
//
// The interesting case is the array-like object: a QV4 sequence (Qt 6.12)
// reports typeof "object" with a numeric length but fails Array.isArray,
// which is what previously made WindowService drop every KWin snapshot.
import { toArray } from "./PayloadArray.mjs";

let errors = 0;
function check(desc, actual, expected) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) {
        console.log("OK:   " + desc + " -> " + a);
    } else {
        errors++;
        console.log("FAIL: " + desc + " -> " + a + " (expected " + e + ")");
    }
}

// Genuine arrays pass through untouched (same identity, not a copy).
const real = [1, 2, 3];
check("real array identity", toArray(real) === real, true);

// QV4 sequence shape: object with numeric length and indexed entries.
const sequence = { length: 3, 0: "a", 1: "b", 2: "c" };
check("array-like sequence", toArray(sequence), ["a", "b", "c"]);
check("empty sequence", toArray({ length: 0 }), []);
check("sequence keeps null holes", toArray({ length: 1 }), [undefined]);

// Not array-like: every other shape must stay null so "missing list" and
// "empty list" remain distinguishable.
check("null", toArray(null), null);
check("undefined", toArray(undefined), null);
check("object", toArray({ a: 1 }), null);
check("string is not an array", toArray("abc"), null);
check("number", toArray(5), null);
check("boolean", toArray(true), null);
check("function", toArray(function () {}), null);

console.log(errors ? "\n" + errors + " FAILED" : "\nAll 11 passed");
process.exit(errors ? 1 : 0);
