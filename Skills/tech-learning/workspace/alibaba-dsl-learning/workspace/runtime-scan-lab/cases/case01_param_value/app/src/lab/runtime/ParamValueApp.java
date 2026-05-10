package lab.runtime;

public class ParamValueApp {
    public static void run() {
        String tainted = SourceApi.getTainted();
        HeaderSink.setHeader("Location", tainted);
        HeaderSink.setHeader("X-Other", tainted);
        HeaderSink.setHeader("Location", "safe");
    }
}
