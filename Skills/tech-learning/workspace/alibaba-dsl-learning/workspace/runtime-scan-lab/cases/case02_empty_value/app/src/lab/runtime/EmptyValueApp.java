package lab.runtime;

public class EmptyValueApp {
    public static void run() {
        String tainted = SourceApi.getTainted();
        new WildA(tainted);
        new WildB(tainted);
        new WildA("safe");
    }
}
