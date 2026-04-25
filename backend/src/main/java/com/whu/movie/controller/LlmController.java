package com.whu.movie.controller;

import com.whu.movie.dto.LlmQueryRequest;
import com.whu.movie.dto.LlmQueryResponse;
import com.whu.movie.service.LlmService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/llm")
public class LlmController {

    private final LlmService llmService;

    public LlmController(LlmService llmService) {
        this.llmService = llmService;
    }

    @PostMapping("/query")
    public LlmQueryResponse query(@Valid @RequestBody LlmQueryRequest request) {
        return llmService.query(request.getUserId(), request.getQueryText());
    }
}
