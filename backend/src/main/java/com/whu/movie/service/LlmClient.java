package com.whu.movie.service;

import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestTemplate;

@Component
public class LlmClient {

    private static final Logger log = LoggerFactory.getLogger(LlmClient.class);

    private final RestTemplate restTemplate;

    @Value("${llm.api.base-url}")
    private String llmBaseUrl;

    @Value("${llm.api.key:}")
    private String llmApiKey;

    @Value("${llm.api.model}")
    private String llmModel;

    @Value("${llm.api.enabled:false}")
    private Boolean llmEnabled;

    public LlmClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public String explainRecommendation(String username, String movieTitle, String genres, Float score) {
        String prompt = "你是一个电影推荐助手。用户是" + username
                + "，系统推荐电影《" + movieTitle + "》，类型为" + genres
                + "，预测评分约为" + String.format("%.2f", score)
                + "。请用不超过100字中文口语解释推荐原因。";
        return chatCompletion(prompt);
    }

    public String answerUserQuery(String username, String queryText, List<String> candidateMovieTitles) {
        String prompt = "你是一个电影推荐问答助手。用户是" + username
                + "，用户提问：" + queryText
                + "。可参考候选电影：" + String.join("、", candidateMovieTitles)
                + "。请给出简洁中文建议，不超过120字。";
        return chatCompletion(prompt);
    }

    private String chatCompletion(String prompt) {
        if (!Boolean.TRUE.equals(llmEnabled) || llmApiKey == null || llmApiKey.isBlank()) {
            return "当前为离线模式：未启用LLM密钥，返回默认解释。";
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(llmApiKey);
        Map<String, Object> body = Map.of(
                "model", llmModel,
                "messages", List.of(
                        Map.of("role", "system", "content", "你是一个专业、简洁的电影推荐助手。"),
                        Map.of("role", "user", "content", prompt)
                ),
                "temperature", 0.5
        );

        HttpEntity<Map<String, Object>> request = new HttpEntity<>(body, headers);
        try {
            ResponseEntity<Map> response = restTemplate.exchange(
                    llmBaseUrl + "/chat/completions",
                    HttpMethod.POST,
                    request,
                    Map.class
            );
            Map responseBody = response.getBody();
            if (responseBody == null || !responseBody.containsKey("choices")) {
                log.warn("LLM response missing choices. baseUrl={}, model={}", llmBaseUrl, llmModel);
                return "LLM响应为空，使用默认解释。";
            }
            List<Map<String, Object>> choices = (List<Map<String, Object>>) responseBody.get("choices");
            if (choices.isEmpty()) {
                log.warn("LLM response choices empty. baseUrl={}, model={}", llmBaseUrl, llmModel);
                return "LLM未返回候选结果，使用默认解释。";
            }
            Map<String, Object> message = (Map<String, Object>) choices.get(0).get("message");
            if (message == null) {
                log.warn("LLM response message null. baseUrl={}, model={}", llmBaseUrl, llmModel);
                return "LLM内容为空，使用默认解释。";
            }
            Object content = message.get("content");
            return content == null ? "LLM内容为空，使用默认解释。" : content.toString();
        } catch (HttpStatusCodeException ex) {
            String resp = ex.getResponseBodyAsString();
            if (resp != null && resp.length() > 500) {
                resp = resp.substring(0, 500) + "...(truncated)";
            }
            log.error("LLM HTTP error. status={}, baseUrl={}, model={}, body={}",
                    ex.getStatusCode(), llmBaseUrl, llmModel, resp);
            return "LLM调用失败，使用默认解释。";
        } catch (Exception ex) {
            log.error("LLM call failed. baseUrl={}, model={}, error={}",
                    llmBaseUrl, llmModel, ex.toString());
            return "LLM调用失败，使用默认解释。";
        }
    }
}
