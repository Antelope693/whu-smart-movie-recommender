package com.whu.movie.dto;

import java.util.ArrayList;
import java.util.List;

public class LlmQueryResponse {
    private Integer code;
    private String responseText;
    private List<RecommendationItem> relatedMovies = new ArrayList<>();

    public Integer getCode() {
        return code;
    }

    public void setCode(Integer code) {
        this.code = code;
    }

    public String getResponseText() {
        return responseText;
    }

    public void setResponseText(String responseText) {
        this.responseText = responseText;
    }

    public List<RecommendationItem> getRelatedMovies() {
        return relatedMovies;
    }

    public void setRelatedMovies(List<RecommendationItem> relatedMovies) {
        this.relatedMovies = relatedMovies;
    }
}
