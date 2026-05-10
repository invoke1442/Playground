package lab.runtime;

public class ExcludeTagApp {
    public static void run() {
        String tainted = SourceApi.getTainted();
        TaggedSink.consume(tainted);
        AlwaysSink.consume(tainted);
    }
}
