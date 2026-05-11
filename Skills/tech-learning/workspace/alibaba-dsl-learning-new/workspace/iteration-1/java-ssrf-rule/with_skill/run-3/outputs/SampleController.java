import java.net.URL;
import javax.servlet.http.HttpServletRequest;
import org.springframework.web.client.RestTemplate;

class SampleController {
    void vulnerableUrl(HttpServletRequest request) throws Exception {
        String target = request.getParameter("url");
        new URL(target).openConnection();
    }

    void vulnerableRestTemplate(HttpServletRequest request, RestTemplate restTemplate) {
        String target = request.getParameter("url");
        restTemplate.getForObject(target, String.class);
    }

    void safeUrl(HttpServletRequest request) throws Exception {
        String target = com.alibaba.security.SecurityUtil.checkSSRF(request.getParameter("url"));
        new URL(target).openConnection();
    }

    void safeRestTemplate(HttpServletRequest request, RestTemplate restTemplate) {
        String target = com.alibaba.security.SecurityUtil.checkSSRF(request.getParameter("url"));
        restTemplate.getForObject(target, String.class);
    }
}
