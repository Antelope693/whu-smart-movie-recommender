package com.whu.movie.service;

import com.whu.movie.dto.RatingSubmitRequest;
import com.whu.movie.entity.Rating;
import com.whu.movie.repository.RatingRepository;
import org.springframework.stereotype.Service;

@Service
public class RatingService {

    private final RatingRepository ratingRepository;
    private final RecommendationService recommendationService;

    public RatingService(RatingRepository ratingRepository, RecommendationService recommendationService) {
        this.ratingRepository = ratingRepository;
        this.recommendationService = recommendationService;
    }

    public void submitRating(RatingSubmitRequest request) {
        Rating rating = new Rating();
        rating.setUserId(request.getUserId());
        rating.setMovieId(request.getMovieId());
        rating.setScore(request.getScore());
        rating.setTimestamp(System.currentTimeMillis() / 1000);
        ratingRepository.save(rating);

        // 评分变化后同步触发推荐更新
        recommendationService.refreshRecommendation(request.getUserId(), 10);
    }
}
