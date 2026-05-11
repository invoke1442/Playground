import java.net.URL;
import javax.servlet.http.HttpServletRequest;

class SampleController {
    void vulnerable(HttpServletRequest request) throws Exception {
        String target = request.getParameter("url");
        new URL(target).openConnection();
    }

    void safe(HttpServletRequest request) throws Exception {
        String target = com.alibaba.security.SecurityUtil.checkSSRF(request.getParameter("url"));
        new URL(target).openConnection();
    }
}
