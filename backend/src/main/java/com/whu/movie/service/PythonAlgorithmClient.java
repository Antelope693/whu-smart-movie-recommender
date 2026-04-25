package com.whu.movie.service;

import com.whu.movie.dto.PythonRecommendRequest;
import com.whu.movie.dto.PythonRecommendResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
public class PythonAlgorithmClient {

    private final RestTemplate restTemplate;

    @Value("${algorithm.service.base-url}")
    private String algorithmServiceBaseUrl;

    public PythonAlgorithmClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public PythonRecommendResponse calculateRecommendation(Integer userId, Integer topN) {
        PythonRecommendRequest request = new PythonRecommendRequest(userId, topN);
        HttpEntity<PythonRecommendRequest> entity = new HttpEntity<>(request);
        ResponseEntity<PythonRecommendResponse> response = restTemplate.exchange(
                algorithmServiceBaseUrl + "/api/python/calculate",
                HttpMethod.POST,
                entity,
                PythonRecommendResponse.class
        );
        return response.getBody();
    }
}
