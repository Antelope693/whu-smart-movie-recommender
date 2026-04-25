package com.whu.movie.dto;

import java.util.List;

public class PythonRecommendResponse {
    private Integer userId;
    private List<PythonRecommendation> recommendations;

    public Integer getUserId() {
        return userId;
    }

    public void setUserId(Integer userId) {
        this.userId = userId;
    }

    public List<PythonRecommendation> getRecommendations() {
        return recommendations;
    }

    public void setRecommendations(List<PythonRecommendation> recommendations) {
        this.recommendations = recommendations;
    }

    public static class PythonRecommendation {
        private Integer movieId;
        private Float score;
        private String reason;

        public Integer getMovieId() {
            return movieId;
        }

        public void setMovieId(Integer movieId) {
            this.movieId = movieId;
        }

        public Float getScore() {
            return score;
        }

        public void setScore(Float score) {
            this.score = score;
        }

        public String getReason() {
            return reason;
        }

        public void setReason(String reason) {
            this.reason = reason;
        }
    }
}
