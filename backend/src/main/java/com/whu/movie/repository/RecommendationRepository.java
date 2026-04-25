package com.whu.movie.repository;

import com.whu.movie.entity.Recommendation;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RecommendationRepository extends JpaRepository<Recommendation, Integer> {
    List<Recommendation> findByUserIdOrderByPredictedScoreDesc(Integer userId);
    void deleteByUserId(Integer userId);
}
