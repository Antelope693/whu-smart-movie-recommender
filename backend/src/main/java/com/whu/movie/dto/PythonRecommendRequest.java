package com.whu.movie.dto;

public class PythonRecommendRequest {
    private Integer userId;
    private Integer topN;

    public PythonRecommendRequest() {
    }

    public PythonRecommendRequest(Integer userId, Integer topN) {
        this.userId = userId;
        this.topN = topN;
    }

    public Integer getUserId() {
        return userId;
    }

    public void setUserId(Integer userId) {
        this.userId = userId;
    }

    public Integer getTopN() {
        return topN;
    }

    public void setTopN(Integer topN) {
        this.topN = topN;
    }
}
