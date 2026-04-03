package org.example.ast;

import java.util.function.Function;

public class AstShowcase {
    private int field = 1;
    private static final String CONST = "const";

    public int demo(int input, Object obj) {
        int a = 1;
        double b = 2.5;
        boolean flag = true;
        String s = "hi";
        Object n = null;
        Class<?> clz = String.class;
        int[] arr = new int[] {1, 2, 3};

        assert input >= 0 : "input must be non-negative";

        a = a + input;
        a += 2;
        a -= 1;
        a *= 3;
        a /= 2;
        a &= 7;
        a >>>= 1;

        int prefix = ++a;
        int postfix = a++;
        boolean notFlag = !flag;
        int bitNot = ~a;

        boolean cmp = (a == input) || (a >= input && a <= input + 10);

        if (obj instanceof String str) {
            s = str + CONST;
        } else if (obj == null) {
            s = "null";
        } else {
            s = String.valueOf(obj);
        }

        for (int i = 0; i < arr.length; i++) {
            if (arr[i] % 2 == 0) {
                continue;
            }
            if (arr[i] > 100) {
                break;
            }
            a += arr[i];
        }

        int j = 0;
        while (j < 2) {
            a = a + j;
            j++;
        }

        int k = 0;
        do {
            k++;
        } while (k < 2);

        switch (a) {
            case 0:
                s = "zero";
                break;
            case 1:
            case 2:
                s = "small";
                break;
            default:
                s = "other";
        }

        try {
            mayThrow(a);
        } catch (IllegalArgumentException ex) {
            s = ex.getMessage();
        } finally {
            s = s + "!";
        }

        final String sForLambda = s;
        Runnable r = () -> System.out.println(this.field + sForLambda);
        Function<Integer, String> f = String::valueOf;
        r.run();
        String converted = f.apply(a);

        Number casted = (Number) Integer.valueOf(converted);
        int ternary = flag ? a : -a;

        AstShowcase created = new AstShowcase();
        created.helper();

        synchronized (this) {
            this.field = this.field + ternary;
        }

        labelBlock:
        {
            if (this.field > 1000) {
                break labelBlock;
            }
            this.field++;
        }

        Outer outer = new Outer();
        Outer.Inner inner = outer.new Inner();
        int outerValue = inner.readOuter();

        return this.field + outerValue + bToInt(b) + (n == null ? 0 : 1) + clz.getName().length() + casted.intValue() + prefix + postfix + (notFlag ? 1 : 0) + bitNot + (cmp ? 1 : 0);
    }

    private int bToInt(double value) {
        return (int) value;
    }

    private void helper() {
        System.out.println(super.toString());
    }

    private void mayThrow(int v) {
        if (v < 0) {
            throw new IllegalArgumentException("v < 0");
        }
    }

    static class Outer {
        private int outerField = 42;

        class Inner {
            int readOuter() {
                return Outer.this.outerField;
            }
        }
    }
}
