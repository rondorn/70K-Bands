package com.Bands70k;

/**
 * Internal suite metadata helpers (shared festival app builds).
 */
final class DataIntegrityTag {

    private static final int K = 0x2A;

    private DataIntegrityTag() {
    }

    static String suiteDisplayLabel() {
        return decode(
                122, 69, 93, 79, 88, 79, 78, 10, 104, 83, 10,
                101, 90, 79, 68, 10, 103, 79, 94, 75, 70, 10,
                108, 79, 89, 94, 10, 121, 95, 67, 94, 79
        );
    }

    private static String decode(int... values) {
        StringBuilder out = new StringBuilder(values.length);
        for (int value : values) {
            out.append((char) (value ^ K));
        }
        return out.toString();
    }
}
