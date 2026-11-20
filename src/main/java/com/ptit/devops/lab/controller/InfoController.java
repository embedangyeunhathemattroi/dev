package com.ptit.devops.lab.controller;

import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
public class InfoController {
    private final Environment environment;
    public InfoController(Environment environment) {
        this.environment = environment;
    }
    @GetMapping(value = "/api/info", produces = "application/json;charset=UTF-8")
    public Map<String, String> info() {
        return Map.of(
                "studentName", environment.getProperty("STUDENT_NAME", ""),
                "studentId", environment.getProperty("STUDENT_ID", ""),
                "studentClass", environment.getProperty("STUDENT_CLASS", ""),
                "examCode", environment.getProperty("EXAM_CODE", "001"),
                "appVersion", environment.getProperty("APP_VERSION", "local"));
    }
}
