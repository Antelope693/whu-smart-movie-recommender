package com.whu.movie.controller;

import com.whu.movie.dto.RatingSubmitRequest;
import com.whu.movie.service.RatingService;
import jakarta.validation.Valid;
import java.util.HashMap;
import java.util.Map;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/rating")
public class RatingController {

    private final RatingService ratingService;

    public RatingController(RatingService ratingService) {
        this.ratingService = ratingService;
    }

    @PostMapping("/submit")
    public Map<String, Object> submit(@Valid @RequestBody RatingSubmitRequest request) {
        ratingService.submitRating(request);
        Map<String, Object> result = new HashMap<>();
        result.put("code", 0);
        result.put("message", "ok");
        return result;
    }
}
