package lab.runtime;

public class SourceApi {
    public static String getTainted() {
        return System.getenv("USER_INPUT");
    }
}
