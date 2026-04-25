package com.whu.movie.service;

import com.whu.movie.dto.LlmQueryResponse;
import com.whu.movie.dto.RecommendationItem;
import com.whu.movie.entity.User;
import com.whu.movie.repository.UserRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class LlmService {

    private final LlmClient llmClient;
    private final RecommendationService recommendationService;
    private final UserRepository userRepository;

    public LlmService(LlmClient llmClient,
                      RecommendationService recommendationService,
                      UserRepository userRepository) {
        this.llmClient = llmClient;
        this.recommendationService = recommendationService;
        this.userRepository = userRepository;
    }

    public LlmQueryResponse query(Integer userId, String queryText) {
        List<RecommendationItem> related = recommendationService.getRecommendationByUserId(userId, 5);
        String username = userRepository.findById(userId).map(User::getUsername).orElse("用户");
        List<String> movieTitles = related.stream()
                .map(item -> item.getTitle() == null ? ("movie-" + item.getMovieId()) : item.getTitle())
                .toList();

        String answer = llmClient.answerUserQuery(username, queryText, movieTitles);
        LlmQueryResponse response = new LlmQueryResponse();
        response.setCode(0);
        response.setResponseText(answer);
        response.setRelatedMovies(related);
        return response;
    }
}
