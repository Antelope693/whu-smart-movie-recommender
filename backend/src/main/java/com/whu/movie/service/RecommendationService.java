package com.whu.movie.service;

import com.whu.movie.dto.PythonRecommendResponse;
import com.whu.movie.dto.RecommendationItem;
import com.whu.movie.entity.Movie;
import com.whu.movie.entity.Recommendation;
import com.whu.movie.entity.User;
import com.whu.movie.repository.MovieRepository;
import com.whu.movie.repository.RecommendationRepository;
import com.whu.movie.repository.UserRepository;
import jakarta.transaction.Transactional;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class RecommendationService {

    private final PythonAlgorithmClient pythonAlgorithmClient;
    private final RecommendationRepository recommendationRepository;
    private final MovieRepository movieRepository;
    private final UserRepository userRepository;
    private final LlmClient llmClient;

    public RecommendationService(PythonAlgorithmClient pythonAlgorithmClient,
                                 RecommendationRepository recommendationRepository,
                                 MovieRepository movieRepository,
                                 UserRepository userRepository,
                                 LlmClient llmClient) {
        this.pythonAlgorithmClient = pythonAlgorithmClient;
        this.recommendationRepository = recommendationRepository;
        this.movieRepository = movieRepository;
        this.userRepository = userRepository;
        this.llmClient = llmClient;
    }

    @Transactional
    public List<RecommendationItem> getRecommendationByUserId(Integer userId, Integer topN) {
        List<Recommendation> existing = recommendationRepository.findByUserIdOrderByPredictedScoreDesc(userId);
        if (existing.isEmpty()) {
            refreshRecommendation(userId, topN);
            existing = recommendationRepository.findByUserIdOrderByPredictedScoreDesc(userId);
        }
        List<RecommendationItem> items = new ArrayList<>();
        for (Recommendation recommendation : existing.stream().limit(topN).toList()) {
            RecommendationItem item = new RecommendationItem();
            item.setMovieId(recommendation.getMovieId());
            item.setScore(recommendation.getPredictedScore());
            item.setReason(recommendation.getReason());

            Optional<Movie> movie = movieRepository.findById(recommendation.getMovieId());
            movie.ifPresent(value -> {
                item.setTitle(value.getTitle());
                item.setGenres(value.getGenres());
            });
            items.add(item);
        }
        return items;
    }

    @Transactional
    public void refreshRecommendation(Integer userId, Integer topN) {
        PythonRecommendResponse response = pythonAlgorithmClient.calculateRecommendation(userId, topN);
        if (response == null || response.getRecommendations() == null) {
            return;
        }
        recommendationRepository.deleteByUserId(userId);
        String username = userRepository.findById(userId).map(User::getUsername).orElse("用户");
        List<Recommendation> toSave = new ArrayList<>();
        for (PythonRecommendResponse.PythonRecommendation pyItem : response.getRecommendations()) {
            Recommendation recommendation = new Recommendation();
            recommendation.setUserId(userId);
            recommendation.setMovieId(pyItem.getMovieId());
            recommendation.setPredictedScore(pyItem.getScore());
            Movie movie = movieRepository.findById(pyItem.getMovieId()).orElse(null);
            String llmReason = null;
            if (movie != null) {
                llmReason = llmClient.explainRecommendation(
                        username,
                        movie.getTitle(),
                        movie.getGenres() == null ? "未知类型" : movie.getGenres(),
                        pyItem.getScore()
                );
            }
            recommendation.setReason(llmReason == null ? pyItem.getReason() : llmReason);
            toSave.add(recommendation);
        }
        recommendationRepository.saveAll(toSave);
    }
}
