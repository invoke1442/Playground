package lab.runtime;

public class FlagApp {
    public static void run() {
        String tainted = SourceApi.getTainted();
        SinkApi.consume(tainted);
    }
}
